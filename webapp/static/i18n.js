(function () {
  var STORAGE_KEY = "platformLanguage";
  var zhToEn = {
    "科研智能计算平台首页": "Scientific Intelligence Platform Home",
    "科研智能计算平台 Logo": "Scientific Intelligence Platform Logo",
    "科研智能计算平台": "Scientific Intelligence Platform",
    "科研智能计算平台｜计算工作区": "Scientific Intelligence Platform | Computing Workspace",
    "科研智能计算平台，集成材料建模、结果可视化与迁移势垒分析等科研工具。": "A scientific intelligence platform for materials modeling, result visualization, and migration-barrier analysis.",
    "科研智能计算平台全部功能模块。": "All function modules on the Scientific Intelligence Platform.",
    "功能模块｜科研智能计算平台": "Function Modules | Scientific Intelligence Platform",
    "平台导航": "Platform navigation",
    "首页": "Home",
    "功能": "Functions",
    "功能模块": "Function modules",
    "全部模块": "All modules",
    "声子结果可视化": "Phonon Results Visualization",
    "生成力常数": "Force Constants Generation",
    "合作单位": "Partners",
    "散裂中子源科学中心": "Spallation Neutron Source Science Center",
    "东华理工大学": "East China University of Technology",
    "语言": "Language",
    "登录": "Sign in",
    "我的账户": "My account",
    "面向科学计算的": "Built for Scientific Computing",
    "一体化智能科研平台": "Integrated Intelligent Research Platform",
    "集成 NEPHONON 结果可视化、力常数生成与 FastTrack-NEP 迁移势垒分析。 各模块保持独立运行，通过统一入口连接科研工作流，并为后续智能工具持续扩展。": "Integrating NEPHONON visualization, force-constant generation, and FastTrack-NEP migration-barrier analysis. Each module runs independently while sharing one unified entry point for an extensible research workflow.",
    "查看功能模块": "Explore Modules",
    "声子计算数据示意图": "Phonon calculation data illustration",
    "科研计算功能": "Scientific Computing Tools",
    "更多": "More",
    "生成能带、DOS、等频面与 S(Q,E) 等结果图，并支持图像样式调整和下载。": "Generate band, DOS, isosurface, and S(Q,E) plots with adjustable styles and export options.",
    "进入 Plot Workspace": "Open Plot Workspace",
    "上传 CIF 与 NEP 模型文件，调用本地流程生成后续声子计算所需的 FORCE_CONSTANTS。": "Upload CIF and NEP model files to generate FORCE_CONSTANTS for subsequent phonon calculations.",
    "进入 FORCE_CONSTANTS": "Open FORCE_CONSTANTS",
    "进入独立的迁移势垒计算工作区，完成结构输入、势函数选择、任务执行与结果查看。": "Use the independent migration-barrier workspace for structure input, potential selection, task execution, and result review.",
    "进入迁移势垒分析": "Open Migration Analysis",
    "面向声子计算、动力学结构因子可视化与原子迁移势垒分析的科研工具平台。": "A research platform for phonon calculations, dynamic structure-factor visualization, and atomic migration-barrier analysis.",
    "合作与支持单位": "Partners and Supporting Institutions",
    "页脚导航": "Footer navigation",
    "Copyright © 2026 科研智能计算平台. All Rights Reserved.": "Copyright © 2026 Scientific Intelligence Platform. All Rights Reserved.",
    "返回首页": "Back to Home",
    "全部功能模块": "All Function Modules",
    "集中展示当前已接入的科研计算工具。后续新增模块会继续加入此页面，并保持独立运行与统一入口。": "Browse all currently integrated scientific-computing tools. New modules will continue to appear here while retaining independent operation and a unified entry point.",
    "当前可用": "Available Now",
    "共 3 个模块": "3 modules",
    "可用": "Available",
    "读取 NEPHONON 输出并生成能带、DOS、等频面与动力学结构因子 S(Q,E) 图像。": "Read NEPHONON output and generate band, DOS, isosurface, and dynamic structure-factor S(Q,E) plots.",
    "进入模块": "Open Module",
    "通过结构文件与 NEP 模型生成 FORCE_CONSTANTS，为后续声子计算准备输入数据。": "Generate FORCE_CONSTANTS from structure files and an NEP model for subsequent phonon calculations.",
    "完成原子迁移势垒分析，包括结构输入、势函数选择、任务执行与计算结果查看。": "Analyze atomic migration barriers, including structure input, potential selection, task execution, and result review.",
    "Copyright © 2026 科研智能计算平台": "Copyright © 2026 Scientific Intelligence Platform",
    "返回平台首页": "Back to Platform Home",
    "账户登录｜科研智能计算平台": "Sign In | Scientific Intelligence Platform",
    "科研智能计算平台账户登录与注册。": "Sign in to or register for the Scientific Intelligence Platform.",
    "欢迎回来": "Welcome back",
    "登录科研智能计算平台。": "Sign in to the Scientific Intelligence Platform.",
    "账户操作": "Account actions",
    "注册": "Register",
    "邮箱": "Email",
    "密码": "Password",
    "创建平台账户": "Create an account",
    "注册后将自动登录。": "You will be signed in automatically after registration.",
    "显示名称": "Display name",
    "确认密码": "Confirm password",
    "密码至少 8 个字符，最长 128 个字符。": "Use 8–128 characters for your password.",
    "创建账户": "Create account",
    "账户创建时间": "Account created",
    "进入功能模块": "Open Function Modules",
    "退出登录": "Sign out",
    "注册账户｜科研智能计算平台": "Register | Scientific Intelligence Platform",
    "我的账户｜科研智能计算平台": "My Account | Scientific Intelligence Platform",
    "两次输入的密码不一致。": "The passwords do not match.",
    "请求失败，请稍后再试。": "The request failed. Please try again later.",
    "账户数据库尚未配置。": "The account database is not configured.",
    "账户数据库状态暂时无法读取。": "The account database status is temporarily unavailable.",
    "账户服务暂时无法连接。": "The account service is temporarily unavailable.",
    "请先登录后再使用功能模块。": "Please sign in before using a function module."
  };

  var enToZh = {};
  Object.keys(zhToEn).forEach(function (key) { enToZh[zhToEn[key]] = key; });

  function normalize(value) {
    return String(value || "").trim().replace(/\s+/g, " ");
  }

  function currentLanguage() {
    try {
      var saved = localStorage.getItem(STORAGE_KEY);
      if (saved === "en" || saved === "zh") return saved;
    } catch (_error) {}
    return document.documentElement.lang.toLowerCase().startsWith("en") ? "en" : "zh";
  }

  function translate(value, language) {
    var normalized = normalize(value);
    if (!normalized) return value;
    if (language === "en") return zhToEn[normalized] || normalized;
    return enToZh[normalized] || normalized;
  }

  function replaceTextNode(node, language) {
    if (!node.nodeValue || !node.nodeValue.trim()) return;
    var parent = node.parentElement;
    if (!parent || /^(SCRIPT|STYLE|NOSCRIPT|TEXTAREA)$/.test(parent.tagName) || parent.closest("[data-i18n-ignore]")) return;
    var leading = (node.nodeValue.match(/^\s*/) || [""])[0];
    var trailing = (node.nodeValue.match(/\s*$/) || [""])[0];
    var translated = translate(node.nodeValue, language);
    if (normalize(node.nodeValue) !== translated) node.nodeValue = leading + translated + trailing;
  }

  function apply(language, remember) {
    var selected = language === "en" ? "en" : "zh";
    var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
    var nodes = [];
    while (walker.nextNode()) nodes.push(walker.currentNode);
    nodes.forEach(function (node) { replaceTextNode(node, selected); });

    ["aria-label", "title", "placeholder", "alt"].forEach(function (attribute) {
      document.querySelectorAll("[" + attribute + "]").forEach(function (element) {
        var value = element.getAttribute(attribute);
        var translated = translate(value, selected);
        if (translated !== normalize(value)) element.setAttribute(attribute, translated);
      });
    });

    document.title = translate(document.title, selected);
    var description = document.querySelector('meta[name="description"]');
    if (description) description.content = translate(description.content, selected);
    document.documentElement.lang = selected === "en" ? "en" : "zh-CN";
    document.querySelectorAll("[data-language-switch]").forEach(function (button) {
      var active = button.getAttribute("data-language-switch") === selected;
      button.classList.toggle("active", active);
      button.setAttribute("aria-pressed", active ? "true" : "false");
    });
    if (remember !== false) {
      try { localStorage.setItem(STORAGE_KEY, selected); } catch (_error) {}
    }
    window.dispatchEvent(new CustomEvent("platformlanguagechange", { detail: { language: selected } }));
  }

  document.addEventListener("click", function (event) {
    var button = event.target.closest("[data-language-switch]");
    if (!button) return;
    apply(button.getAttribute("data-language-switch"), true);
  });

  window.PlatformI18n = {
    apply: apply,
    current: currentLanguage,
    t: function (value) { return translate(value, currentLanguage()); }
  };
  apply(currentLanguage(), false);
})();
