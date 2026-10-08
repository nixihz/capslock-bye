(() => {
  "use strict";

  const english = {
    skip: "Skip to content",
    nav_label: "Main navigation",
    nav_how: "How it works",
    nav_install: "Getting started",
    language_label: "Language",
    hero_eyebrow: "A small keyboard utility for Mac",
    hero_line1: "Tap for Esc.",
    hero_line2: "Hold for Hyper.",
    hero_description:
      "Give Caps Lock a job you actually need. Tap to escape; hold for a whole new layer of shortcuts. Right where your little finger rests.",
    download: "Download for Mac",
    hero_explore: "See how it works",
    download_note: "macOS 14+ · Apple Silicon & Intel",
    proof_free: "Free & open source",
    proof_notarized: "Apple notarized",
    proof_local: "Keys processed locally",
    demo_live: "Interactive demo",
    stage_caption: "Same key. A different job.",
    key_label:
      "Try Caps Lock: tap for Escape, hold for 180 milliseconds for Hyper",
    demo_controls_label: "Choose a demo",
    tap: "Tap",
    hold: "Hold",
    demo_instruction:
      "Click or hold the key above, or choose Tap / Hold below.",
    strip_intro: "One less thing to reach for.",
    strip_native: "Native macOS",
    strip_account: "No account",
    strip_driver: "No driver",
    strip_menubar: "Lives in your menu bar",
    how_eyebrow: "Tap & hold",
    how_title: "Keep your hands on the home row.",
    how_description:
      "Escape is next to your little finger. Four modifiers fit under one key.",
    tap_title: "Tap to escape.",
    tap_description:
      "Leave insert mode in Vim, dismiss a dialog, or cancel an action. Esc is always close by.",
    tap_footnote: "Choose another key or record your own shortcut.",
    hold_title: "Hold for your shortcuts.",
    hold_description:
      "Hyper combines ⌘ ⌃ ⌥ ⇧. Bind it with another key in your favorite tools to make room for more shortcuts.",
    hold_footnote:
      "180 ms by default. Another key activates the chord immediately.",
    product_alt:
      "CapsLock Bye on macOS, showing tap for Escape, hold for Hyper, and mapping active",
    product_caption: "Actual app · macOS 26",
    product_eyebrow: "A native Mac app",
    product_line1: "Close the window.",
    product_line2: "Keep the shortcuts.",
    product_description:
      "Once mapping is on, close the window and get back to work. CapsLock Bye stays in your menu bar.",
    feature_custom_title: "Make it feel right",
    feature_custom_description:
      "Choose your tap shortcut, hold modifiers, and timing. Try your changes in the built-in key tester.",
    feature_local_title: "Your typing stays on your Mac",
    feature_local_description:
      "Keys are processed locally. The app never records or uploads what you type. No account or driver required.",
    feature_native_title: "At home on macOS",
    feature_native_description:
      "English and Chinese, with optional launch at login. Liquid Glass on macOS 26; system materials on 14–15.",
    install_eyebrow: "Getting started",
    install_title: "A quick setup, then back to work.",
    release_link: "Latest release & checksums",
    install1_title: "Add it to Applications",
    install1_description:
      "Download the latest DMG. Open it, drag CapsLock Bye into Applications, then launch the app.",
    install1_detail: "Signed and Apple notarized",
    install2_title: "Allow two permissions",
    install2_description:
      "Follow the app’s guide to enable Accessibility and Input Monitoring in System Settings → Privacy & Security. Reopen the app if prompted.",
    install2_detail: "Needed to receive keys and send mapped actions",
    install3_title: "Try your new key",
    install3_description:
      "Enable mapping and try tap and hold in the key tester. Close the window to keep the app in your menu bar.",
    install3_detail: "Left-click to open · Right-click to pause or quit",
    faq_eyebrow: "Before you install",
    faq_title: "A few things to know.",
    faq_help: "Ask a question on GitHub",
    faq1_question: "What is Hyper? Does it launch apps for me?",
    faq1_answer:
      "Hyper is Command, Control, Option, and Shift pressed together. CapsLock Bye sends these modifiers. Assign Hyper plus another key to an action in Alfred, Raycast, or another tool that supports custom shortcuts.",
    faq2_question: "Can I use it with other key remappers?",
    faq2_answer:
      "Disable other tools’ Caps Lock mappings, and leave Caps Lock at its default in your keyboard firmware and macOS settings. This avoids multiple tools remapping the same key.",
    faq3_question: "Why does it stop working in some password fields?",
    faq3_answer:
      "Mapping pauses while macOS Secure Input is active, including in some password fields. It resumes automatically when Secure Input ends.",
    faq4_question: "I granted permissions. Why isn’t mapping working?",
    faq4_answer:
      "Try turning Accessibility permission off and on again. For Input Monitoring, fully quit and reopen the app. If the app is missing from the list, add it with the + button. Still stuck? Open an issue with your macOS version and keyboard model.",
    faq5_question: "Is it free? Which Macs does it support?",
    faq5_answer:
      "Free and open source under MIT. It requires macOS 14 or later. The universal installer supports Apple Silicon and Intel. Each release includes a DMG and its SHA256 checksum file.",
    closing_eyebrow: "CapsLock Bye",
    closing_title: "Put Caps Lock to work.",
    closing_description: "Free, open source, and ready for your Mac.",
    footer_description: "Tap for Esc. Hold for Hyper.",
    footer_source: "Source",
    footer_feedback: "Report an issue",
  };

  // Chinese lives in the HTML so the page remains readable without JavaScript.
  const localizedNodes = [];
  for (const [attribute, target] of [
    ["data-i18n", null],
    ["data-i18n-aria", "aria-label"],
    ["data-i18n-alt", "alt"],
  ]) {
    document.querySelectorAll(`[${attribute}]`).forEach((element) => {
      localizedNodes.push({
        element,
        key: element.getAttribute(attribute),
        target,
        chinese: target ? element.getAttribute(target) : element.textContent,
      });
    });
  }

  const metadata = {
    zh: {
      title: "CapsLock Bye · 轻点 Esc，按住 Hyper",
      description:
        "轻点 Caps Lock 发送 Esc，按住变成 Hyper。免费、开源的原生 macOS 菜单栏工具，按键在本机处理。支持 macOS 14+、Apple Silicon 和 Intel。",
      announcement: {
        tap: "轻点 Caps Lock：发送 Esc。",
        hold: "按住 Caps Lock：发送 Hyper，Command、Control、Option、Shift。",
      },
    },
    en: {
      title: "CapsLock Bye · Tap for Esc. Hold for Hyper.",
      description:
        "Tap Caps Lock for Escape. Hold for Hyper. A free, open-source, native Mac menu bar app. Keys are processed locally. macOS 14+, Apple Silicon and Intel.",
      announcement: {
        tap: "Tap Caps Lock: Escape.",
        hold: "Hold Caps Lock: Hyper, Command, Control, Option, Shift.",
      },
    },
  };
  let language = "zh";
  let mode = "tap";
  const demo = document.querySelector(".interactive-demo");
  const key = document.getElementById("caps-key");
  const announcement = document.getElementById("demo-announcement");
  const tapButton = document.getElementById("demo-tap");
  const holdButton = document.getElementById("demo-hold");

  function showMode(nextMode, announce = true) {
    mode = nextMode;
    demo.dataset.mode = mode;
    tapButton.setAttribute("aria-pressed", String(mode === "tap"));
    holdButton.setAttribute("aria-pressed", String(mode === "hold"));
    demo.querySelector(".output-name").textContent =
      mode === "tap" ? "ESCAPE" : "HYPER";
    demo.querySelector(".output-symbol").textContent =
      mode === "tap" ? "esc" : "⌘⌃⌥⇧";
    demo.querySelector(".stage-coordinate").textContent =
      mode === "tap" ? "01 / 02" : "02 / 02";
    if (announce)
      announcement.textContent = metadata[language].announcement[mode];
  }

  function setLanguage(nextLanguage) {
    language = nextLanguage === "en" ? "en" : "zh";
    document.documentElement.lang = language === "en" ? "en" : "zh-CN";
    for (const {
      element,
      key: translationKey,
      target,
      chinese,
    } of localizedNodes) {
      const value =
        language === "en" ? english[translationKey] || chinese : chinese;
      if (target) element.setAttribute(target, value);
      else element.textContent = value;
    }
    document.title = metadata[language].title;
    document.querySelector('meta[name="description"]').content =
      metadata[language].description;
    document.querySelector('meta[property="og:title"]').content =
      metadata[language].title;
    document.querySelector('meta[property="og:description"]').content =
      metadata[language].description;
    document
      .getElementById("btn-zh")
      .setAttribute("aria-pressed", String(language === "zh"));
    document
      .getElementById("btn-en")
      .setAttribute("aria-pressed", String(language === "en"));
    if (announcement.textContent)
      announcement.textContent = metadata[language].announcement[mode];
    try {
      localStorage.setItem("capslock-bye-lang", language);
    } catch {
      /* Storage may be disabled. */
    }
  }

  document
    .getElementById("btn-zh")
    .addEventListener("click", () => setLanguage("zh"));
  document
    .getElementById("btn-en")
    .addEventListener("click", () => setLanguage("en"));
  tapButton.addEventListener("click", () => showMode("tap"));
  holdButton.addEventListener("click", () => showMode("hold"));

  // A website demo only: it does not intercept or remap physical keyboard input.
  const holdThreshold = 180;
  let activePointer = null;
  let startedAt = 0;
  let holdTimer = null;
  let previousMode = "tap";
  let held = false;

  function clearPress() {
    clearTimeout(holdTimer);
    holdTimer = null;
    const pointer = activePointer;
    activePointer = null;
    key.classList.remove("is-pressed");
    if (pointer !== null && key.hasPointerCapture(pointer))
      key.releasePointerCapture(pointer);
  }

  function cancelPress(event) {
    if (activePointer === null) return;
    if (
      event &&
      typeof event.pointerId === "number" &&
      event.pointerId !== activePointer
    )
      return;
    clearPress();
    showMode(previousMode);
  }

  key.addEventListener("pointerdown", (event) => {
    if (activePointer !== null || !event.isPrimary || event.button !== 0)
      return;
    activePointer = event.pointerId;
    previousMode = mode;
    held = false;
    startedAt = performance.now();
    key.setPointerCapture(activePointer);
    key.classList.add("is-pressed");
    holdTimer = setTimeout(() => {
      held = true;
      showMode("hold");
    }, holdThreshold);
  });

  key.addEventListener("pointerup", (event) => {
    if (event.pointerId !== activePointer) return;
    const result =
      held || performance.now() - startedAt >= holdThreshold ? "hold" : "tap";
    clearPress();
    showMode(result);
  });
  key.addEventListener("pointercancel", cancelPress);
  key.addEventListener("lostpointercapture", cancelPress);
  // Enter/Space and assistive technology use native button activation, instantly.
  key.addEventListener("click", (event) => {
    if (event.detail === 0) showMode("tap");
  });
  key.addEventListener("contextmenu", (event) => event.preventDefault());
  window.addEventListener("blur", cancelPress);
  document.addEventListener("visibilitychange", () => {
    if (document.hidden) cancelPress();
  });
  document.addEventListener("keydown", () =>
    document.documentElement.classList.add("keyboard-input"),
  );
  document.addEventListener(
    "pointerdown",
    () => document.documentElement.classList.remove("keyboard-input"),
    { capture: true },
  );

  let initialLanguage = navigator.language?.toLowerCase().startsWith("en")
    ? "en"
    : "zh";
  try {
    const saved = localStorage.getItem("capslock-bye-lang");
    if (saved === "zh" || saved === "en") initialLanguage = saved;
  } catch {
    /* Browser language still works without storage. */
  }
  const requestedLanguage = new URLSearchParams(window.location.search).get(
    "lang",
  );
  if (requestedLanguage === "zh" || requestedLanguage === "en")
    initialLanguage = requestedLanguage;
  setLanguage(initialLanguage);
})();
