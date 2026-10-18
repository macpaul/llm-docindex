# **針對多格式文件與簡報存取之AI Agent Token優化機制及Skill工程實踐**

## **第一章：AI Agent 上下文視窗優化之必要性與底層運作機制**

隨著大型語言模型（LLM）的上下文視窗（Context Window）不斷擴展至數十萬甚至上百萬的等級，將海量文件直接輸入給AI Agent已成為架構設計上的一種可能。然而，直接存取未經處理的原始文件格式（如HTML、PDF、Word、PPTX與XML等）會帶來極度嚴重的Token浪費與運算成本膨脹。原始文件包含了龐大且對機器理解毫無助益的排版標籤、視覺元資料、底層腳本代碼以及冗餘的XML樹狀結構。  
在具體的資源消耗評估中，若將一份包含豐富視覺排版與圖表的20頁PDF報告直接送入模型，並利用視覺模型進行逐頁柵格化（Rasterization）處理，其Token消耗量可能高達40,000至70,000 Tokens1。相對地，若能透過轉換機制將其降維為純文字的Markdown格式，則僅需約10,000至15,000 Tokens，整體的成本節省幅度可輕易超過80%1。同樣的現象也發生在網頁擷取上，一份僅包含500字實質內容的HTML網頁，往往因為伴隨的DOM（文件物件模型）結構與樣板（Boilerplate）而產生高達5,000至20,000 Tokens的負擔3。  
因此，為了構建具備低延遲、高準確度且極具成本效益的AI Agent，開發團隊必須在資料輸入端與修改輸出端實施嚴格的Token節約與過濾機制。這不僅涉及將半結構化或非結構化的文件降維至高資訊密度的純文字格式，更需要利用抽象語法樹（AST）進行深度剪枝，或是利用語言伺服器協定（LSP）來精確提取語意特徵。此外，為了使Agent能夠自主決定何時以及如何調用這些優化操作，開發者必須將這些底層機制封裝為標準化的Agent Skills。本報告將從多種主流文件格式的底層結構出發，深入剖析當前業界最頂尖的Token壓縮機制與工具，並詳細闡述如何透過Model Context Protocol (MCP)、Claude Code SKILL.md以及Google Antigravity等框架，將其轉化為Agent能夠自主調用的工程最佳實踐。

## **第二章：辦公室文件與簡報格式（PDF, DOCX, PPTX）之降維與增量讀寫策略**

辦公室軟體產出的文件與簡報（如PDF、Word、Excel、PowerPoint）構成了多數企業知識庫的核心。這些格式本質上是高度複雜的壓縮演算法產物或視覺渲染指令集。例如，.docx與.pptx檔案基於開放打包約定（Open Packaging Conventions, OPC），其內部為一個ZIP壓縮檔，包含了大量的XML配置節點與關聯的元資料4。若允許LLM直接讀取或修改底層的XML結構，將耗費巨量的Token於解讀樣式表與字型標籤。業界的標準解決方案分為「讀取時的降維提取」與「寫入時的增量修補」。

### **讀取端的降維生態系：MarkItDown、Docling與PyMuPDF4LLM**

為了最大化資訊密度，讀取文件的最佳實踐是將其降維（Flattening）為Markdown格式。Markdown以極低的標記符號保留了文件的主體結構，包含標題層級、清單、表格與強調語氣。目前在此領域存在三種設計哲學截然不同的工具。  
微軟開源的MarkItDown是一款專為LLM資料攝取而設計的輕量級Python工具，廣泛支援PDF、DOCX、PPTX、XLSX及HTML等格式5。其架構優勢在於極快的處理速度與極低的系統依賴。在處理DOCX與PPTX時，MarkItDown能夠無縫提取標題層級，並將表格轉換為GFM（GitHub Flavored Markdown）表格，甚至能將Excel中的各個工作表直接展平為獨立的Markdown表格6。此外，它還支援透過外掛機制的擴充，例如結合LLM視覺模型進行圖片描述，或是利用Azure Document Intelligence來強化光學字元辨識（OCR）5。然而，MarkItDown在處理PDF時主要依賴 pdfminer 進行文字層的順序提取，這意味著它將PDF視為扁平的文字流。對於包含多欄位排版、無文字層的掃描件或複雜內部表格的PDF，其結構還原能力顯著不足，經常遺失原有的標題層級，或將表格拆解為難以閱讀的文字碎片5。  
相較於MarkItDown追求的輕量與全域轉換，IBM開源的Docling則採用了深度的文件理解（Document Understanding）運算管線。它並非單純的格式轉換器，而是一個結合了版面分析（Layout Analysis）、閱讀順序偵測、表格結構辨識與OCR引擎的複雜系統9。Docling能夠極度精準地重建多欄位文章的合理閱讀順序，並將高度複雜的學術論文或企業財報表格完美轉譯為Markdown或結構化的JSON資料11。這種結構保真度對於依賴語意切塊（Chunking）的檢索增強生成（RAG）系統而言是不可或缺的。其伴隨的代價是極高的運算資源消耗，處理單頁文件往往需要數秒鐘，且需要在初次啟動時下載高達數百MB的機器學習模型權重11。  
若應用場景僅聚焦於原生數位PDF（非掃描件），且極度重視吞吐量與處理速度，PyMuPDF4LLM提供了第三種選擇。作為PyMuPDF的專門擴展，它不依賴任何深度學習模型，處理單頁僅需數毫秒，並能生成附帶頁面元資料（如邊界框Bounding Boxes）的Markdown輸出9。對於大規模的純數位PDF語料庫批次處理，這是兼具速度與Token節約率的最佳解。

| 評估維度 | MarkItDown | Docling | PyMuPDF4LLM |
| :---- | :---- | :---- | :---- |
| **系統架構定位** | 輕量級多格式通用轉換器 (LLM預處理) | 深度文件理解與結構重建機器學習管線 | 極速本地PDF轉Markdown擴展模組 |
| **Token 節省表現** | 優異 (高度純文字化，徹底剔除所有XML與視覺冗餘) | 良好 (保留豐富的版面與座標結構元資料) | 優異 (快速剔除版面噪音並保留基礎結構) |
| **轉換處理速度** | 極快 (毫秒級至秒級，視格式而定) | 緩慢 (高度依賴模型推理，每頁耗時數秒) | 極快 (毫秒級，無模型載入開銷) |
| **複雜PDF與表格解析** | 較弱 (文字流順序提取，易丟失欄位與表格結構) | 極佳 (內建版面與表格結構識別專用模型) | 中等 (依賴底層PDF文字區塊資訊進行重組) |
| **DOCX/PPTX/XLSX 支援** | 極佳 (原生支援，含Excel工作表完整解析) | 良好 (原生支援DOCX與PPTX之解析) | 無 (專注於PDF文件處理) |
| **典型應用場景** | Agent日常跨格式快速讀取、高效率預覽 | 複雜學術論文、財報、多欄位排版深度解析 | 大規模純數位PDF語料庫之高吞吐量批次處理 |

### **寫入端的革命：XML增量編輯與節點修補技術**

解決了讀取時的Token浪費問題後，Agent面臨的下一個挑戰是如何在不消耗大量輸出Token（Output Tokens）的情況下「修改」文件。當Agent需要更新一份DOCX或PPTX文件時，若要求LLM輸出整份文件的Markdown並重新轉譯為DOCX，不僅會消耗數萬個輸出Token，更極易在轉譯過程中破壞原有的企業級樣式表、頁首頁尾與浮水印設定。  
工程上的最佳實踐是採用XML增量修改（Incremental Edit）與節點修補（Node Patching）策略。以DOCX為例，其實際內容主要儲存於壓縮包內的 word/document.xml 中，而自訂屬性或中繼資料則位於 docProps/custom.xml 內14。透過將 python-docx 與 lxml 庫封裝為Agent的專用工具，Agent不再需要處理整份文件。相反地，它只需輸出目標節點的XPath與所需的替換內容，即可在底層完成精準修改14。  
例如，若Agent需要更新合約中的生效日期，它可以呼叫一個節點修補工具，並僅需傳入類似 {"action": "update\_xml", "xpath": "//w:t\[text()='2025'\]", "new\_text": "2026"} 的JSON結構。底層腳本會利用 lxml.etree 解析 word/document.xml，找到對應的 \<w:t\> 標籤並替換其文字，隨後將修改後的XML重新打包入DOCX14。這種微創手術般的編輯方式，將原本需要數千Token的寫入操作，壓縮至不到50個Token的工具呼叫，徹底消除了大型檔案重寫的上下文浪費與格式損壞風險16。

## **第三章：網頁、DOM與Wiki結構之噪音過濾與純化技術**

在處理網路爬蟲抓取的HTML與Wiki資料時，Agent面臨著與辦公室文件截然不同的噪音來源。現代網頁的DOM（文件物件模型）樹充滿了導航列、側邊欄、廣告追蹤器、腳註與動態腳本等非主要內容。將未經處理的完整DOM樹送入LLM，不僅會浪費高達90%的Token，更可能因為大量無關的語意資訊干擾模型的注意力機制（Attention Mechanism），進而導致幻覺或產生錯誤的摘要結論3。  
針對HTML的純化，開發界發展出多種基於啟發式規則與演算法的過濾工具。Trafilatura 是一個功能強大且備受推崇的Python套件，專注於從原始HTML中提取主要文本，並將其轉化為高結構化的Markdown或JSON資料。它結合了深度的XPath規則庫與Readability演算法作為後備機制20。在多項基準測試中，Trafilatura展現了極高的準確率（F1 Score 達 0.859 至 0.91 以上），能夠極為有效地剝離樣板噪音，將動輒數萬Token的雜亂網頁壓縮至僅剩幾千Token的核心內容21。Trafilatura的一大優勢在於其對多語系內容的卓越原生支援，能夠在無需額外配置的情況下處理各種語言的網頁內容23。  
另一派主流作法是基於瀏覽器生態系的 Readability (Mozilla) 搭配 Turndown 轉換器。Readability 透過計算DOM節點的文字密度與樣式特徵來評分，進而精確識別出文章主體的子樹22。當這套組合運行於瀏覽器擴充功能或Node.js環境中（搭配 jsdom 或更輕量的 linkedom），展現了極高的內容保真度，在部分長篇散文測試中的F1分數甚至略勝Trafilatura23。然而，Readability演算法的設計高度偏向「單一文章結構」，面對高度巢狀結構的現代前端框架網頁（如包含多個獨立區塊的儀表板或論壇清單）時，容易出現誤判，導致包含重要資訊的節點被意外丟棄23。  
為解決上述兩者的痛點，Readdown 這類專為AI應用優化的輕量級工具應運而生。Readdown 將內容提取、Markdown轉換與Token估算機制整合為單一且無外部依賴的套件。相較於傳統的 readability \+ turndown 組合（依賴兩個套件與膠水代碼，壓縮後約65KB），Readdown 的體積僅約5KB。在基準測試中，它不僅在保留完整標題層級與解析排版表格方面表現更佳，且整體執行速度提升了約40%（例如解析190KB的維基百科Markdown僅需219毫秒），為Agent提供了極具時效性的網頁純化能力24。

| 比較維度 | Trafilatura | Readability \+ Turndown | Readdown |
| :---- | :---- | :---- | :---- |
| **底層技術架構** | XPath 啟發式規則混合演算法回退機制 | 節點文字密度與樣式評分演算法 | 單一套件整合式DOM樹提取與轉換 |
| **生態系與語言** | Python (依賴 lxml 等底層庫) | JavaScript (Node.js 或瀏覽器環境) | JavaScript (無額外依賴) |
| **平均 F1 分數** | \~0.91 (部分基準測試達0.859) | \~0.94 (在單一長篇文章表現極佳) | N/A (著重於保留完整結構與極速解析) |
| **執行效能表現** | 中等 (在極度複雜DOM上可能達數百毫秒) | 快 (若扣除 jsdom 初始化開銷則極快) | 極快 (相較於前者提速約 40%) |
| **多語系與邊界處理** | 極佳 (原生支援各種語系與複雜中繼資料) | 良好 (但遇到非文章結構容易截斷內容) | 優異 (精確保留標題層級與解除表格包裝) |

## **第四章：結構化文件、程式碼與XML的AST語義壓縮技術**

對於高度結構化的內容（如大型原始碼儲存庫、結構化XML配置檔、或是包含眾多依賴關係的文件集），單純的Markdown降維已不足以應付Agent的需求。在這些場景中，核心挑戰在於如何讓Agent在有限的上下文視窗內「理解」整體的架構拓撲，而不必讀取每個模組的實作細節。為此，業界引入了基於抽象語法樹（AST）、語言伺服器協定（LSP）與SCIP（SCIP Code Intelligence Protocol）的語意壓縮與檢索技術。

### **AST 壓縮與符號檢索（Repomix 與 TokToken）**

在處理大型儲存庫時，Repomix 引入了基於 Tree-sitter 的 AST 壓縮技術。當 Agent 需要分析一個專案的架構時，Repomix 可以動態地剖析程式碼或結構化文本，並透過啟動 \--compress 參數，僅保留函數簽名、類別結構、介面定義以及重要的結構元素，而徹底剔除所有的實作細節與方法主體25。這種智慧型壓縮能夠將整體Token數量削減70%以上，使原本高達百萬Token的專案能夠輕鬆塞入標準模型的上下文視窗中，讓Agent得以在宏觀層面把握架構，並在需要時才深入特定檔案26。  
另一項極端優化的實踐是 TokToken，它是一款使用 C 語言編寫的單一二進位工具，整合了 universal-ctags 與 SQLite FTS5 引擎29。TokToken 放棄了讀取整份檔案的傳統作法，改為提供精確的「符號級檢索」。當Agent需要某個函數的邏輯時，它可以發出符號搜尋指令，TokToken 會追蹤依賴關係並僅返回該函數及相關引用的實作代碼。這種機制避免了Agent為了尋找一個函數而讀取數千行無關代碼的窘境，使得每次存取操作的Token消耗量銳減 88% 至 99%29。

### **拓撲映射與語意索引（Aider Repo Map 與 SCIP）**

為了讓LLM在不讀取細節的情況下仍能具備全域視野，Aider 開發了儲存庫映射（Repo Map）技術。Aider 會掃描專案內的所有檔案，利用 Tree-sitter 或 ctags 提取出所有的實體符號與引用關係，並構建出一個相鄰矩陣（Adjacency Matrix）圖譜32。隨後，Aider 應用 PageRank 演算法對這個圖譜進行計算，評估每個符號與檔案在整個專案中的「重要性」與「關聯度」33。最終，Aider 僅將排名最高的關鍵符號定義與其所屬檔案的路徑注入到 LLM 的上下文視窗中。這種高度濃縮的 Repo Map 賦予了 Agent 宛如具備領域專家直覺的導航能力，使其能夠精準判斷需要修改的目標檔案32。  
在更深層次的語意理解上，Sourcegraph 提出的 SCIP (SCIP Code Intelligence Protocol) 成為了跨語言知識圖譜建構的標準。不同於基於 AST 的靜態解析，SCIP 索引器（如 scip-typescript、scip-python、scip-go）會利用編譯器或語言本身的類型系統進行深度分析，解析出精確的定義、引用與實作關係36。當Agent需要查詢某個介面的所有實作時，它可以透過 scip-search 工具直接查詢 SCIP 索引，而不是使用耗費大量Token且容易產生雜訊的常規文字搜尋（如 grep）36。透過 scip-io 這類多語言索引協調器，Agent 可以一鍵生成整個混合語言專案的語意索引，大幅降低了代碼導航時的盲目探索成本38。

### **混合 LSP 分析的優勢（Serena MCP 與 Pyright）**

儘管 Tree-sitter 在語法提取上極為快速，但它缺乏理解程式碼語意與動態類型推導的能力。這正是 Serena MCP 等高階工具引入語言伺服器協定（LSP）的原因40。Serena 透過運行真實的 LSP 伺服器（如 Python 的 Pyright、Rust 的 rust-analyzer），賦予了 Agent 類似現代 IDE 的結構理解能力40。  
以 Python 為例，相較於 Tree-sitter 只能看到字面上的變數名稱，Pyright 具備流程敏感型別推導（Flow-sensitive typing）與 PEP 695 泛型支援。它可以精確判斷一個變數在經過一系列條件判斷後的具體型別，並找出跨模組的真實方法定義44。當 Agent 呼叫 Serena MCP 進行「尋找所有引用」或「重新命名符號」時，它依賴的是 LSP 強大的型別解析引擎，從而確保了重構操作的絕對安全與精準40。然而，執行 LSP 伺服器會帶來顯著的記憶體開銷（例如 rust-analyzer 在大型專案中極其耗費記憶體），因此在架構設計上，如何管理這些伺服器的生命週期與資源，成為了優化的另一個核心課題47。

## **第五章：將優化機制轉化為 Model Context Protocol (MCP) 伺服器**

上述所有針對文件降維、XML增量修補、AST壓縮與LSP分析的底層技術，唯有將其封裝為 Agent 能夠自主發現與調用的標準化工具，才能真正發揮自動化的威力。Model Context Protocol (MCP) 正是為了解決 LLM 與外部工具通訊瓶頸而誕生的標準化協定。透過建立 MCP 伺服器，開發者可以將各種優化腳本暴露為一組結構化的 API，供任何相容 MCP 的客戶端（如 Claude Desktop、Cursor、Windsurf 等）無縫調用29。

### **FastMCP 框架的深度實踐**

在 Python 生態系中，FastMCP 已成為建構 MCP 伺服器的主流框架。它借鑒了 FastAPI 的設計哲學，開發者只需撰寫標準的 Python 函數，並加上 @mcp.tool 裝飾器，FastMCP 便會利用 Python 的型別提示（Type Hints）與 Docstring 自動生成 LLM 所需的工具描述與精確的 JSON Schema50。  
為了確保工具註冊與業務邏輯的清晰分離，應對不斷擴張的工具集，業界建議採用類似 SEP-1575 規範的模組化架構。在這種架構下，專案被劃分為伺服器進入點（如 server.py）與業務邏輯模組（如 tools/ 目錄）52。

Python  
\# 伺服器進入點範例 (server.py)  
from fastmcp import FastMCP  
from tools.document\_parser import convert\_to\_markdown  
from tools.xml\_patcher import patch\_docx\_xml

\# 實例化 FastMCP 伺服器  
mcp \= FastMCP(name="Enterprise-Document-Optimizer")

\# 透過 @mcp.tool 將外部業務邏輯註冊為 Agent Tool  
@mcp.tool  
def read\_document\_optimized(file\_path: str) \-\> str:  
    """  
    讀取PDF、DOCX、PPTX或HTML，並利用MarkItDown/Docling將其轉換為Markdown。  
    此工具可剔除視覺與XML冗餘，將Token消耗降低至原先的20%。  
    適用於內容理解、大綱擷取與表格分析。  
    """  
    return convert\_to\_markdown(file\_path)

@mcp.tool  
def incremental\_docx\_update(file\_path: str, xpath\_query: str, new\_text: str) \-\> dict:  
    """  
    透過增量XML修補技術更新DOCX文件。  
    無需要求Agent重寫整份文件，只需提供目標節點的XPath與替換文本，  
    大幅節省輸出Token並避免破壞原有的排版樣式。  
    """  
    return patch\_docx\_xml(file\_path, xpath\_query, new\_text)

if \_\_name\_\_ \== "\_\_main\_\_":  
    \# 支援 stdio 傳輸供本地CLI使用，亦支援HTTP/SSE供容器化部署  
    mcp.run(transport="stdio") 

FastMCP 不僅處理簡單的文字轉換，它還內建了強大的型別處理機制，能夠自動將回傳的位元組資料編碼為 MCP 協定中的 EmbeddedResource，或是將 Image、Audio 類別轉換為對應的媒體內容區塊50。更進階地，透過 PrefabApp，FastMCP 甚至能讓工具回傳視覺化的 UI 元件樹，供支援的客戶端進行豐富的介面渲染53。在依賴管理上，FastMCP 支援類似 FastAPI 的依賴注入機制（使用 Depends），允許在執行期間動態注入會話資訊或資料庫連線，而無需將這些參數暴露給 LLM50。  
以微軟官方發布的 markitdown-mcp 套件為例，它完美展示了 MCP 伺服器的整合威力。開發者只需在 Claude Desktop 的設定檔中新增幾行 JSON 宣告，將執行指令指向 markitdown-mcp，Agent 便立刻具備了呼叫 convert\_to\_markdown(uri) 工具的能力。無論目標是本地的 Excel 報表還是遠端的 PDF 檔案，Agent 都能夠在極低的 Token 成本下取得乾淨的 Markdown 內容54。

### **同步與非同步架構的效能考量**

在建構與語言伺服器或底層系統互動的 MCP 伺服器時，架構的同步與非同步設計對延遲有決定性的影響。例如在 rust-analyzer-mcp 的實作中，開發者發現若盲目引入複雜的非同步執行期（如 Tokio），反而會因為執行緒池分配與計時器輪詢增加啟動延遲。由於 MCP 伺服器通常作為 Agent 的子進程以 1:1 的 stdio 管道進行通訊，採用基於同步通道（如 sync\_channel(1)）的三執行緒架構，能夠實現低於 2 毫秒的極速冷啟動，並確保在 LSP 進程崩潰時能夠確定性地釋放資源58。這種追求極致效能的架構設計，對於頻繁呼叫代碼檢索與 XML 修補工具的 Agent 而言至關重要。

## **第六章：基於 SKILL.md 規範的 Agent 與 CLI Skills 封裝與調度**

除了建立常駐的 MCP 伺服器外，另一種更加靈活且便於版本控制的方法，是將優化機制封裝為基於目錄與 Markdown 檔案的 Agent Skills。無論是 Claude Code 還是 Google Antigravity，皆採用了 SKILL.md 的開放規範來定義 Agent 的行為邊界與作業程序。

### **漸進式揭露與 Claude Code Skills**

Claude Code Skills 的核心設計哲學在於「漸進式揭露」（Progressive Disclosure）。一個標準的 Skill 是一個包含 SKILL.md 檔案與輔助腳本（如 scripts/）的目錄。在對話初期，為了保護珍貴的上下文視窗，Agent 並不會讀取所有安裝技能的詳細內容，而只會看見每個技能的名稱與簡短的 YAML 描述59。只有當使用者的 Prompt 意圖與某個技能的描述高度匹配時，Agent 才會進一步載入 SKILL.md 的完整指令。  
在此機制下，我們可以定義一個專責處理文件讀寫的技能：

## **name: docx-token-optimizer description: Parses DOCX and PDF into strict Markdown for low-token analysis, and allows incremental patching of XML to save output tokens.**

# **Document Optimization Skill**

## **When to use**

Use this skill whenever you need to read or modify a .docx, .pdf, .pptx, or .html file. DO NOT attempt to read the raw binary files directly.

## **Instructions**

> 1. **Reading**: Execute the scripts/markitdown\_runner.py to convert the target file to markdown. Read the markdown output instead of the original file.  
> 2. **Modifying (DOCX only)**: DO NOT generate the full markdown and ask the user to save it as DOCX. Instead, use scripts/patch\_xml.py \--file \<file\> \--find \<text\> \--replace \<text\> to incrementally patch the document XML.

## **Best Practices**

* For large PDFs, always prefer markdown conversion to avoid vision-model token costs.  
* When patching XML, ensure the search string is highly specific.

透過這種具有強烈約束力的標準作業程序（SOP），Agent 將不再盲目地嘗試讀取二進位檔案，而是嚴格依循腳本指令進行降維與修補，大幅降低了操作失敗率與資源消耗63。

### **Google Antigravity 的技能體系與全域調度**

Google Antigravity（涵蓋其 Desktop App、IDE 與 CLI 工具 agy）將 Agent 的上下文管理推向了更細緻的層次。它將上下文劃分為 Rules、Skills、Knowledge 與 Artifacts，其中 Skills 專門用於封裝可重複執行的程序59。  
在 Antigravity 的生態系中，SKILL.md 頂部的 YAML Frontmatter 扮演了極為關鍵的角色。其中的 description 欄位實質上充當了「觸發短語」（Trigger Phrase）60。由於底層模型是依賴該描述的語意相關性來決定是否自動載入技能，開發者必須撰寫極度精確的說明。例如，不能僅將其描述為「文件處理工具」，而應具體說明：「執行將PDF、PPTX與DOCX轉換為Markdown以節省Token，並支援基於XML的Word文件增量修改，適用於資料擷取與自動化報告生成」60。  
Antigravity 對於技能的作用域（Scope）有著嚴格的管理機制：

> 1. **專案級工作區 (Workspace Scope)**：存放於專案根目錄的 /.agents/skills/（亦相容舊版的 .agent/skills/）。這非常適合將特定於該專案的文件範本轉換邏輯與代碼一起提交至 Git 儲存庫，供開發團隊共用60。  
> 2. **全域級 (Global Scope)**：存放於 \~/.gemini/config/skills/。適合存放如 markitdown-converter 這種跨專案通用的文件降維技能，使其在使用者系統上的任何目錄中均可被 Agent 呼叫60。

實戰中需要注意的是，Antigravity 的全域載入器僅會掃描 \~/.gemini/config/skills/ 下的一層目錄來尋找 SKILL.md。若開發者希望統一管理所有技能（例如將所有技能集中存放於某個特定資料夾），最佳實踐是在終端機建立符號連結（Symlink），例如執行 ln \-s \~/.agents/skills \~/.gemini/config/skills。這樣不僅繞過了無法使用單一 JSON 配置檔指向全域技能的限制，也確保了所有安裝的代理技能均能被 CLI 與 IDE 正確識別與載入67。  
在執行與安全管理層面，使用者除了依賴 Agent 的自主推論（Autonomous Invocation）外，亦可在 CLI 中透過輸入 / 加上技能名稱（如 /docx-token-optimizer）來強制觸發技能59。此外，針對執行環境的安全性，開發者可透過修改 \~/.gemini/antigravity-cli/settings.json 檔案中的配置來建立安全邊界。例如，將 toolPermission 設定為 request-review 或限定於 enableTerminalSandbox 的沙盒模式內執行，並設定 artifactReviewPolicy，確保 Agent 在執行 Python 文件轉換腳本或對原始 XML 進行增量寫入前，必須經過人類的最終審查與核准68。這種機制完美平衡了自動化的效率與企業資料的安全性。

## **第七章：綜合應用、工具定義最佳實踐與結論**

在實作任何 Agent Tools 時，除了上述的架構設計外，如何撰寫出能被 LLM 正確理解與調用的工具定義，本身就是一門工程學問。根據實戰經驗，開發者應避免使用模糊的自然語言描述參數，而應大量使用 Pydantic 模型、Literal 型別與嚴謹的 JSON Schema 來限制 LLM 可以輸入的參數範圍69。此外，工具的回傳值不應僅是簡單的字串或原始的例外錯誤（Raw Exceptions），而應採用結構化的錯誤回應（例如包含 error\_type 與 suggestion），並針對會寫入檔案的操作加入冪等性金鑰（Idempotency Keys）。這樣的設計能引導 Agent 在遭遇解析錯誤或找不到對應的 XML 節點時，自主調整策略或發起重試，而非陷入無意義的幻覺迴圈中69。

### **結論**

在 AI Agent 逐漸深入企業工作流的進程中，上下文視窗（Context Window）的精細化管理不僅是降低 API 呼叫成本的財務手段，更是提升大型語言模型注意力集中度與任務成功率的底層基礎。本報告深入探討了如何透過多層次的技術手段，徹底解決 HTML、PDF、DOCX 等各式複雜文件格式帶來的 Token 膨脹問題。  
從讀取端來看，我們見證了生態系的多元發展。利用 MarkItDown 或 Trafilatura 進行輕量級的純文字降維，能夠輕易實現 70% 至 90% 的 Token 壓縮率；對於需要極致結構保真度的場景，Docling 的深度版面分析則提供了無可取代的價值。在理解程式碼與結構化文本方面，基於 Tree-sitter 的 AST 壓縮（如 Repomix）、結合 PageRank 演算法的 Repo Map（如 Aider），以及基於 SCIP 與 LSP 協定的語意索引，共同為 Agent 勾勒出了一幅無需閱讀細節即可導航全域的拓撲地圖。  
從寫入端來看，我們必須徹底摒棄讓 LLM 全文本覆寫二進位檔案的危險作法。轉而採用基於 lxml 的 XML 節點增量修補（Node Patching）技術，是確保企業文件樣式不被破壞、並將輸出 Token 降至極致的唯一可靠路徑。  
進一步地，透過 FastMCP 框架將這些底層優化機制封裝為標準化的 MCP 伺服器，或利用 Claude Code 與 Google Antigravity 的 SKILL.md 規範實現技能的漸進式揭露與全域路由，開發者得以將複雜的工程細節與 Agent 的推論邏輯完美分離。Agent 不再需要直接與原始的二進位位元組搏鬥，而是透過高階、語意化且嚴格受限的介面與世界互動。隨著工具生態的持續成熟，未來的 AI Agent 將能以幾近完美的精準度與極低的資源成本，在海量且跨格式的企業知識庫中自由穿梭與操作。

#### **引用的著作**

> 1. Convert PDF to Markdown to Save LLM Tokens: The MarkItDown, [https\://agentsroom.dev/blog/convert-pdf-to-markdown-save-tokens](https://agentsroom.dev/blog/convert-pdf-to-markdown-save-tokens)  
> 2. 把PDF 轉成Markdown 以節省LLM token：MarkItDown 實戰指南, [https\://agentsroom.dev/zh-TW/blog/convert-pdf-to-markdown-save-tokens](https://agentsroom.dev/zh-TW/blog/convert-pdf-to-markdown-save-tokens)  
> 3. How to Convert Files to Markdown to Reduce AI Token Usage by Up, [https\://www\.mindstudio.ai/blog/convert-files-markdown-reduce-ai-tokens](https://www.mindstudio.ai/blog/convert-files-markdown-reduce-ai-tokens)  
> 4. Evidence Divergence in OOXML-to-LLM Ingestion \- arXiv, [https\://arxiv.org/pdf/2608.25880](https://arxiv.org/pdf/2608.25880)  
> 5. MarkItDown vs Pandoc: Which Document Converter Should You Use?, [https\://www\.file2markdown.ai/blog/markitdown-vs-pandoc](https://www.file2markdown.ai/blog/markitdown-vs-pandoc)  
> 6. Word、PPT 一鍵轉成Markdown，餵AI 前先「瘦身」大省 ... \- 軟體玩家, [https\://pcrookie.com/microsoft-markitdown-convert-files-to-markdown/](https://pcrookie.com/microsoft-markitdown-convert-files-to-markdown/)  
> 7. MarkItDown Review: The File-to-Markdown Converter That Isn't, [https\://thunderbit.com/blog/markitdown-review](https://thunderbit.com/blog/markitdown-review)  
> 8. 微軟開源超好用工具MarkItDown：把PDF、Word、PPT 一鍵轉成AI, [https\://www\.kocpc.com.tw/archives/638475](https://www.kocpc.com.tw/archives/638475)  
> 9. MarkItDown vs Docling vs PyMuPDF4LLM: Which Is Best for PDF to, [https\://docs.bswen.com/blog/2026-08-20-markitdown-docling-pymupdf4llm-comparison/](https://docs.bswen.com/blog/2026-08-20-markitdown-docling-pymupdf4llm-comparison/)  
> 10. 透過Docling 輕鬆解析常見文件，匯出成JSON、Markdown \- IT 空間, [https\://blog.jiatool.com/posts/docling\_intro/](https://blog.jiatool.com/posts/docling_intro/)  
> 11. PyMuPDF4LLM vs Docling: Which PDF-to-Markdown Library Should, [https\://www\.file2markdown.ai/blog/pymupdf4llm-vs-docling](https://www.file2markdown.ai/blog/pymupdf4llm-vs-docling)  
> 12. Docling — Turn complex documents into structured data your AI can, [https\://docling.ai/](https://docling.ai/)  
> 13. PDF to markdown for LLMs: Marker vs Docling vs MarkItDown vs, [https\://anyformat.ai/blog/pdf-to-markdown-for-llms](https://anyformat.ai/blog/pdf-to-markdown-for-llms)  
> 14. Python Series. Publishing code on PyPI: mod\_docx XML… \- Medium, [https\://medium.com/@j622amilah/publishing-code-on-pypi-mod-docx-xml-document-manipulation-f5e89efaf1bc](https://medium.com/@j622amilah/publishing-code-on-pypi-mod-docx-xml-document-manipulation-f5e89efaf1bc)  
> 15. How to modify custom.xml within docx using python \- Stack Overflow, [https\://stackoverflow.com/questions/39694652/how-to-modify-custom-xml-within-docx-using-python](https://stackoverflow.com/questions/39694652/how-to-modify-custom-xml-within-docx-using-python)  
> 16. docx: Automate reading, creating, and editing DOCX documents, [https\://skills.rest/skill/docx-cccnam5158](https://skills.rest/skill/docx-cccnam5158)  
> 17. Working with Custom XML \- python-docx-oss documentation, [https\://python-docx-oss.readthedocs.io/en/latest/user/custom-xml.html](https://python-docx-oss.readthedocs.io/en/latest/user/custom-xml.html)  
> 18. AI friendly edit functions \#1568 \- python-openxml/python-docx \- GitHub, [https\://github.com/python-openxml/python-docx/issues/1568](https://github.com/python-openxml/python-docx/issues/1568)  
> 19. What is HTML to markdown conversion in web scraping? \- Firecrawl, [https\://www\.firecrawl.dev/glossary/web-extraction-apis/what-is-html-to-markdown-conversion-web-scraping](https://www.firecrawl.dev/glossary/web-extraction-apis/what-is-html-to-markdown-conversion-web-scraping)  
> 20. Trafilatura: discover web content, extract text and metadata, [https\://trafilatura.readthedocs.io/](https://trafilatura.readthedocs.io/)  
> 21. trafilatura \- PyPI, [https\://pypi.org/project/trafilatura/](https://pypi.org/project/trafilatura/)  
> 22. WCXB: A Multi-Type Web Content Extraction Benchmark \- arXiv, [https\://arxiv.org/pdf/2605.21097](https://arxiv.org/pdf/2605.21097)  
> 23. Readability vs Trafilatura vs jsdom: 2026 Benchmark \- BulkMD, [https\://www\.bulkmd.app/blog/readability-vs-trafilatura-extractors](https://www.bulkmd.app/blog/readability-vs-trafilatura-extractors)  
> 24. zcag/readdown: HTML to clean Markdown optimized for ... \- GitHub, [https\://github.com/zcag/readdown](https://github.com/zcag/readdown)  
> 25. repomix \- PyPI, [https\://pypi.org/project/repomix/](https://pypi.org/project/repomix/)  
> 26. Code Compression | Repomix, [https\://repomix.com/guide/code-compress](https://repomix.com/guide/code-compress)  
> 27. 一个工具压缩代码减少70% token，还能自动扫密钥 \- 腾讯云, [https\://cloud.tencent.com/developer/article/2670370](https://cloud.tencent.com/developer/article/2670370)  
> 28. Repomix Codebase Packer (Grade A) \- Claude Skill \- Skills Directory, [https\://www\.skillsdirectory.com/skills/carloscape-repomix-codebase-packer](https://www.skillsdirectory.com/skills/carloscape-repomix-codebase-packer)  
> 29. TokToken is a fast, single-binary C codebase indexer for AI ... \- GitHub, [https\://github.com/mauriziofonte/toktoken](https://github.com/mauriziofonte/toktoken)  
> 30. TokToken | MCP Servers · LobeHub, [https\://lobehub.com/mcp/mauriziofonte-toktoken](https://lobehub.com/mcp/mauriziofonte-toktoken)  
> 31. I built a CLI tool that saves 88-99% of tokens when AI agents explore, [https\://www\.reddit.com/r/LLMDevs/comments/1rwzmwk/i\_built\_a\_cli\_tool\_that\_saves\_8899\_of\_tokens\_when/](https://www.reddit.com/r/LLMDevs/comments/1rwzmwk/i_built_a_cli_tool_that_saves_8899_of_tokens_when/)  
> 32. Repository map \- Aider, [https\://aider.chat/docs/repomap.html](https://aider.chat/docs/repomap.html)  
> 33. Improving aider's repo map to do large, simple refactors automatically., [https\://engineering.meetsmore.com/entry/2024/12/24/042333](https://engineering.meetsmore.com/entry/2024/12/24/042333)  
> 34. Adjacency List \- iT 邦幫忙::一起幫忙解決難題，拯救IT 人的一天, [https\://ithelp.ithome.com.tw/articles/10331526](https://ithelp.ithome.com.tw/articles/10331526)  
> 35. Building a better repository map with tree sitter \- Aider, [https\://aider.chat/2023/10/22/repomap.html](https://aider.chat/2023/10/22/repomap.html)  
> 36. SCIP Search CLI \- liza-mas \- GitHub, [https\://github.com/liza-mas/scip-search/](https://github.com/liza-mas/scip-search/)  
> 37. SCIP Code Intelligence Protocol \- GitHub, [https\://github.com/scip-code/scip](https://github.com/scip-code/scip)  
> 38. SCIP-IO \- SCIP Index Orchestrator : r/sourcegraph \- Reddit, [https\://www\.reddit.com/r/sourcegraph/comments/1se20qd/scipio\_scip\_index\_orchestrator/](https://www.reddit.com/r/sourcegraph/comments/1se20qd/scipio_scip_index_orchestrator/)  
> 39. scip-typescript: a new TypeScript and JavaScript indexer, [https\://sourcegraph.com/blog/announcing-scip-typescript](https://sourcegraph.com/blog/announcing-scip-typescript)  
> 40. Serena MCP: Setup, Prompts & Alternatives (2026) \- Paralect, [https\://www\.paralect.com/mcp/serena](https://www.paralect.com/mcp/serena)  
> 41. How to make AI code edits more accurate \- DEV Community, [https\://dev.to/siddhantkcode/how-to-make-ai-code-edits-more-accurate-bbe](https://dev.to/siddhantkcode/how-to-make-ai-code-edits-more-accurate-bbe)  
> 42. Knowledge Graph Tools for AI Code Agents | Antão Almada, [https\://antaoalmada.dev/posts/Code-Agent-Knowledge-Graphs/](https://antaoalmada.dev/posts/Code-Agent-Knowledge-Graphs/)  
> 43. MCP Language Server, [https\://mcp.so/servers/mcp-language-server](https://mcp.so/servers/mcp-language-server)  
> 44. Suggesting Python Code Type Annotations with LLM \- Texera, [https\://texera.io/suggesting-python-code-type-annotations-with-llm-a-language-server-enhancement/](https://texera.io/suggesting-python-code-type-annotations-with-llm-a-language-server-enhancement/)  
> 45. Pyright Guide: Installation, Configuration, and Use Cases, [https\://www\.analyticsvidhya.com/blog/2026/03/pyright-guide/](https://www.analyticsvidhya.com/blog/2026/03/pyright-guide/)  
> 46. Pyright: The Type Checker Python Deserved All Along, [https\://python.plainenglish.io/pyright-the-type-checker-python-deserved-all-along-728379c3a8af](https://python.plainenglish.io/pyright-the-type-checker-python-deserved-all-along-728379c3a8af)  
> 47. rust\_analyzer is eating my memory, any counter measure? \- Reddit, [https\://www\.reddit.com/r/rust/comments/1qkqcqr/rust\_analyzer\_is\_eating\_my\_memory\_any\_counter/](https://www.reddit.com/r/rust/comments/1qkqcqr/rust_analyzer_is_eating_my_memory_any_counter/)  
> 48. serena/CHANGELOG.md at main \- oraios \- GitHub, [https\://github.com/oraios/serena/blob/main/CHANGELOG.md](https://github.com/oraios/serena/blob/main/CHANGELOG.md)  
> 49. Building and deploying a Python MCP server with FastMCP and, [https\://circleci.com/blog/building-and-deploying-a-python-mcp-server-with-fastmcp/](https://circleci.com/blog/building-and-deploying-a-python-mcp-server-with-fastmcp/)  
> 50. Tools \- FastMCP, [https\://gofastmcp.com/servers/tools](https://gofastmcp.com/servers/tools)  
> 51. Building an MCP server for your FastAPI application with FastMCP, [https\://www\.speakeasy.com/mcp/framework-guides/building-fastapi-server](https://www.speakeasy.com/mcp/framework-guides/building-fastapi-server)  
> 52. Document recommended FastMCP server layout and tool version, [https\://github.com/modelcontextprotocol/python-sdk/issues/1681](https://github.com/modelcontextprotocol/python-sdk/issues/1681)  
> 53. Quickstart \- FastMCP, [https\://gofastmcp.com/getting-started/quickstart](https://gofastmcp.com/getting-started/quickstart)  
> 54. MarkItDown MCP — Convert Any File to Markdown for AI \- mdskills, [https\://www\.mdskills.ai/zh/skills/markitdown](https://www.mdskills.ai/zh/skills/markitdown)  
> 55. Python MarkItDown: Convert Documents Into LLM-Ready Markdown, [https\://realpython.com/python-markitdown/](https://realpython.com/python-markitdown/)  
> 56. MarkItDown MCP — Convert Any File to Markdown for AI \- mdskills, [https\://www\.mdskills.ai/skills/markitdown](https://www.mdskills.ai/skills/markitdown)  
> 57. How to Use MarkItDown MCP to Convert the Docs into Markdowns?, [https\://www\.analyticsvidhya.com/blog/2025/04/markitdown-mcp/](https://www.analyticsvidhya.com/blog/2025/04/markitdown-mcp/)  
> 58. To Async or Not to Async: Building a Rust MCP Server for rust, [https\://developerlife.com/2026/08/22/to-async-or-not-to-async-rust-mcp-server/](https://developerlife.com/2026/08/22/to-async-or-not-to-async-rust-mcp-server/)  
> 59. Google Antigravity Rules, Skills, and Workflows Explained, [https\://datalakehousehub.com/blog/2026-03-context-management-google-antigravity/](https://datalakehousehub.com/blog/2026-03-context-management-google-antigravity/)  
> 60. Agent skills | Google Antigravity Docs, [https\://antigravity.google/docs/skills/](https://antigravity.google/docs/skills/)  
> 61. Best Claude Code Skills and SKILL.md Examples in 2026, [https\://promptessor.com/blog/best-claude-code-skills-and-skillmd-examples-for-reusable-coding-workflows-in-2026](https://promptessor.com/blog/best-claude-code-skills-and-skillmd-examples-for-reusable-coding-workflows-in-2026)  
> 62. The SKILL.md Format: Complete Specification and Examples, [https\://aiskill.market/blog/claude-code-skill-md-format](https://aiskill.market/blog/claude-code-skill-md-format)  
> 63. The Complete Guide to Building Skills for Claude | Anthropic, [https\://resources.anthropic.com/hubfs/The-Complete-Guide-to-Building-Skill-for-Claude.pdf](https://resources.anthropic.com/hubfs/The-Complete-Guide-to-Building-Skill-for-Claude.pdf)  
> 64. Extend Claude with skills \- Claude Code Docs, [https\://code.claude.com/docs/en/skills](https://code.claude.com/docs/en/skills)  
> 65. How to create custom skills | Claude Help Center, [https\://support.claude.com/en/articles/12512198-how-to-create-custom-skills](https://support.claude.com/en/articles/12512198-how-to-create-custom-skills)  
> 66. Authoring Google Antigravity Skills \- Codelabs, [https\://codelabs.developers.google.com/getting-started-with-antigravity-skills](https://codelabs.developers.google.com/getting-started-with-antigravity-skills)  
> 67. Google Antigravity & Gemini 4 Argon: How to Load Your Global, [https\://dev.to/gde/google-antigravity-gemini-4-argon-how-to-load-your-global-agents-skills-2cek](https://dev.to/gde/google-antigravity-gemini-4-argon-how-to-load-your-global-agents-skills-2cek)  
> 68. Settings | Google Antigravity Docs, [https\://antigravity.google/docs/settings/](https://antigravity.google/docs/settings/)  
> 69. Write Better AI Agent Tools: 5 Python Patterns LLMs Actually, [https\://dev.to/klement\_gunndu/write-better-ai-agent-tools-5-python-patterns-llms-actually-understand-4m3](https://dev.to/klement_gunndu/write-better-ai-agent-tools-5-python-patterns-llms-actually-understand-4m3)