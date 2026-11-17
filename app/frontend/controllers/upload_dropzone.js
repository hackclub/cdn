// Upload dropzone and clipboard paste controller
(function () {
  let initialized = false;
  let eventsBound = false;
  let form = null;
  let fileInput = null;
  let dragCounter = 0;
  let toastEl = null;
  let tooltip = null;
  let isDropping = false;

  const PREFETCH_SVGS = [
    "/orph-closed-mouth.svg",
    "/orph-open-mouth.svg",
    "/file-icon.svg"
  ];

  const DESKTOP_TITLES = [
    "Feed me, mortal",
    "Drop 'em like it's hot",
    "Your files look delicious",
    "Sacrifice your assets to Orph",
    "Nom nom nom...",
    "Down the hatch",
    "Mmm, fresh uploads"
  ];

  function getRandomTitle() {
    return DESKTOP_TITLES[Math.floor(Math.random() * DESKTOP_TITLES.length)];
  }

  function prefetchSvgAssets() {
    if (!document.head) return;
    PREFETCH_SVGS.forEach((url) => {
      if (!document.querySelector(`link[rel="prefetch"][href="${url}"]`)) {
        const link = document.createElement("link");
        link.rel = "prefetch";
        link.as = "image";
        link.type = "image/svg+xml";
        link.href = url;
        document.head.appendChild(link);
      }
    });
  }

  const CACHE_KEY = "cdn_uploads_cached";
  const RIBBON_CACHE_KEY = "cdn_activity_ribbon_html";

  function applyActivityRibbonHtml(ribbon, html) {
    if (!ribbon || !html) return;
    const temp = document.createElement("div");
    temp.innerHTML = html.trim();
    const newGrid = temp.querySelector(".activity-grid") || temp.querySelector("[class*='activity-grid']") || temp.firstElementChild;
    const oldGrid = ribbon.querySelector(".activity-grid");

    if (newGrid) {
      if (oldGrid) {
        // Prevent hover stutter and layout thrashing if content is already identical
        if (oldGrid.innerHTML !== newGrid.innerHTML) {
          oldGrid.replaceWith(newGrid);
          requestAnimationFrame(() => {
            adjustActivityRibbonColumns(true);
          });
        }
      } else {
        ribbon.appendChild(newGrid);
        requestAnimationFrame(() => {
          adjustActivityRibbonColumns(true);
        });
      }
      ribbon.classList.remove("is-skeleton-loading");
    }
  }

  function scheduleBackgroundRibbonFetch(ribbon, url) {
    let executed = false;

    const runFetch = () => {
      if (executed) return;
      executed = true;

      fetch(url, {
        headers: {
          "Accept": "text/html",
          "X-Requested-With": "XMLHttpRequest"
        }
      })
        .then((res) => {
          if (!res.ok) throw new Error("Ribbon fetch failed");
          return res.text();
        })
        .then((html) => {
          if (html && html.includes("activity-cell")) {
            applyActivityRibbonHtml(ribbon, html);
            try {
              localStorage.setItem(RIBBON_CACHE_KEY, html);
            } catch (_) {}
          }
        })
        .catch((err) => {
          console.warn("Async ribbon load notice:", err);
        });
    };

    // NEVER block page load: wait until window 'load' event fires completely,
    // ensuring browser tab spinner stops immediately and page is fully ready.
    if (document.readyState === "complete") {
      if ("requestIdleCallback" in window) {
        window.requestIdleCallback(runFetch, { timeout: 3000 });
      } else {
        setTimeout(runFetch, 100);
      }
    } else {
      window.addEventListener("load", () => {
        if ("requestIdleCallback" in window) {
          window.requestIdleCallback(runFetch, { timeout: 3000 });
        } else {
          setTimeout(runFetch, 100);
        }
      }, { once: true });
    }
  }

  function refreshRibbonInBackground() {
    const ribbon = document.querySelector("[data-lazy-ribbon]");
    if (!ribbon) return;
    const url = ribbon.getAttribute("data-ribbon-url") || "/uploads/activity_ribbon";
    fetch(url, {
      headers: {
        "Accept": "text/html",
        "X-Requested-With": "XMLHttpRequest"
      }
    })
      .then((res) => (res.ok ? res.text() : null))
      .then((html) => {
        if (html && html.includes("activity-cell")) {
          applyActivityRibbonHtml(ribbon, html);
          try {
            localStorage.setItem(RIBBON_CACHE_KEY, html);
          } catch (_) {}
        }
      })
      .catch(() => {});
  }

  function loadLazyActivityRibbon() {
    const ribbon = document.querySelector("[data-activity-ribbon]");
    if (!ribbon) return;

    const existingGrid = ribbon.querySelector(".activity-grid");
    if (existingGrid) {
      // Activity graph is already server-side rendered (instant like GitHub)!
      // No delayed fetch or skeleton needed!
      ribbon.classList.remove("is-skeleton-loading");
      adjustActivityRibbonColumns(true);
      return;
    }

    const url = ribbon.getAttribute("data-ribbon-url") || "/uploads/activity_ribbon";

    // 1. Instant Cache: Check localStorage if not already rendered
    let cachedHtml = null;
    try {
      cachedHtml = localStorage.getItem(RIBBON_CACHE_KEY);
    } catch (_) {}

    if (cachedHtml && cachedHtml.includes("activity-cell")) {
      applyActivityRibbonHtml(ribbon, cachedHtml);
    }

    // 2. Schedule background network revalidation AFTER window load
    // The main page finishes loading immediately (stopping the tab spinner)
    // while the activity ribbon revalidates independently in the background
    scheduleBackgroundRibbonFetch(ribbon, url);
  }

  function handleLoadingLifecycle() {
    const container = document.querySelector("[data-uploads-container]");
    if (!container) return;

    // Real content is rendered server-side: display content immediately without artificial delays
    container.classList.remove("is-skeleton-loading");
    container.classList.add("is-loaded");

    try {
      sessionStorage.setItem(CACHE_KEY, "true");
    } catch (_) {}
  }

  function init() {
    loadLazyActivityRibbon();
    requestAnimationFrame(() => {
      adjustActivityRibbonColumns();
      setupRibbonResizeObserver();
    });
    handleLoadingLifecycle();

    const formElement = document.querySelector("[data-dropzone-form]");
    if (!formElement) {
      form = null;
      fileInput = null;
      initialized = false;
      return;
    }

    if (initialized && form === formElement) return;

    form = formElement;
    fileInput = form.querySelector("[data-dropzone-input]");
    if (!fileInput) return;

    initialized = true;

    // Handle standard manual file picker change: directly upload without Orph or suction
    fileInput.addEventListener("change", (e) => {
      const files = e.target.files;
      if (files && files.length > 0) {
        directUpload(files);
      }
    });

    convertPageFlashToToast();

    if (!eventsBound) {
      bindDragAndDropEvents();
      bindPasteEvents();
      bindActivityTooltipEvents();
      bindActivityClickScrollEvents();
      bindSingleDeleteForms();
      eventsBound = true;
    }

    bindOrphCompanion();
    prefetchSvgAssets();
  }

  function truncateMiddle(str, maxLength = 28) {
    if (!str || typeof str !== "string") return "";
    if (str.length <= maxLength) return str;
    const charsToShow = maxLength - 1; // 1 for ellipsis character '…'
    const frontChars = Math.ceil(charsToShow / 2);
    const backChars = Math.floor(charsToShow / 2);
    return str.slice(0, frontChars) + "…" + str.slice(str.length - backChars);
  }

  function formatToastMessage(message) {
    if (!message || typeof message !== "string") return "";
    return message.replace(/"([^"]+)"/g, (match, filename) => {
      return `"${truncateMiddle(filename, 28)}"`;
    });
  }

  function convertPageFlashToToast() {
    const flashWrapper = document.querySelector("body > div[style*='max-width: 768px']");
    if (!flashWrapper) return;

    const successFlash = flashWrapper.querySelector(".flash-success, [class*='flash-success']");
    const dangerFlash = flashWrapper.querySelector(".flash-danger, [class*='flash-danger'], [class*='flash-error']");

    if (successFlash) {
      const msg = successFlash.textContent.trim();
      flashWrapper.remove();
      if (msg) showSuccessToast(msg);
    } else if (dangerFlash) {
      const msg = dangerFlash.textContent.trim();
      flashWrapper.remove();
      if (msg) showErrorToast(msg);
    }
  }

  function showUploadToast(count) {
    if (toastEl) toastEl.remove();

    toastEl = document.createElement("div");
    toastEl.className = "upload-status-toast";
    toastEl.innerHTML = `
      <div class="upload-spinner"></div>
      <span class="upload-toast-text">Uploading ${count} ${count === 1 ? "file" : "files"}...</span>
    `;
    document.body.appendChild(toastEl);
  }

  function hasFiles(e) {
    if (!e.dataTransfer || !e.dataTransfer.types) return false;
    for (let i = 0; i < e.dataTransfer.types.length; i++) {
      if (e.dataTransfer.types[i] === "Files") return true;
    }
    return false;
  }

  function isInsideDropZone(e) {
    if (e.target && e.target.closest) {
      if (e.target.closest("[data-hero-stage]") || e.target.closest("[data-upload-card]")) {
        return true;
      }
    }
    const card = document.querySelector("[data-upload-card]");
    if (card && typeof e.clientX === "number" && typeof e.clientY === "number" && (e.clientX !== 0 || e.clientY !== 0)) {
      const rect = card.getBoundingClientRect();
      if (
        e.clientX >= rect.left &&
        e.clientX <= rect.right &&
        e.clientY >= rect.top &&
        e.clientY <= rect.bottom
      ) {
        return true;
      }
    }
    return false;
  }

  // When files are dragged anywhere into the browser window:
  // Show Orph with mouth CLOSED and fun text / speech bubble
  function showOrphScreenDrag(card) {
    if (isDropping) return;
    const orphStage = card.querySelector("[data-orph-stage]");
    const titleEl = card.querySelector("[data-dropzone-title]");
    const bubble = card.querySelector("[data-orph-bubble]");

    card.classList.add("drag-active");
    if (orphStage) {
      orphStage.classList.remove("mouth-open", "gulping");
    }
    if (titleEl) {
      titleEl.textContent = getRandomTitle();
    }
    if (bubble) {
      bubble.textContent = "Feed me files!";
    }
  }

  // When cursor enters the drop region:
  // Open Orph's mouth and set prompt
  function enterDropZoneTarget(card) {
    if (isDropping) return;
    const orphStage = card.querySelector("[data-orph-stage]");
    const bubble = card.querySelector("[data-orph-bubble]");

    card.classList.add("drag-target");
    if (orphStage) {
      orphStage.classList.add("mouth-open");
      orphStage.classList.remove("gulping");
    }
    if (bubble) {
      bubble.textContent = "Drop it here!";
    }
  }

  // When cursor leaves the drop region back to elsewhere on screen:
  // Close Orph's mouth, but keep Orph visible (drag-active stays)
  function leaveDropZoneTarget(card) {
    if (isDropping) return;
    const orphStage = card.querySelector("[data-orph-stage]");
    const bubble = card.querySelector("[data-orph-bubble]");

    card.classList.remove("drag-target");
    if (orphStage) {
      orphStage.classList.remove("mouth-open", "gulping");
    }
    if (bubble) {
      bubble.textContent = "Feed me files!";
    }
  }

  // When drag session ends (dragleave window or cancelled drop):
  // Deactivate Orph and return cleanly to resting view
  function deactivateOrphScreenDrag(card) {
    if (isDropping) return;
    const orphStage = card.querySelector("[data-orph-stage]");
    const bubble = card.querySelector("[data-orph-bubble]");
    const leftPupil = card.querySelector("[data-orph-pupil-left]");
    const rightPupil = card.querySelector("[data-orph-pupil-right]");

    card.classList.remove("drag-active", "drag-target");
    if (orphStage) {
      orphStage.classList.remove("mouth-open", "gulping");
    }
    if (bubble) {
      bubble.textContent = "Nom nom!";
    }
    if (leftPupil) leftPupil.style.transform = "translate(-50%, -50%)";
    if (rightPupil) rightPupil.style.transform = "translate(-50%, -50%)";
  }

  function bindDragAndDropEvents() {
    window.addEventListener("dragenter", (e) => {
      if (!hasFiles(e)) return;
      dragCounter++;
      e.preventDefault();

      if (dragCounter === 1) {
        const cards = document.querySelectorAll("[data-upload-card]");
        const inside = isInsideDropZone(e);

        cards.forEach((card) => {
          showOrphScreenDrag(card);
          if (inside) {
            enterDropZoneTarget(card);
          }
        });
      }
    });

    window.addEventListener("dragover", (e) => {
      if (!hasFiles(e)) return;
      e.preventDefault();

      const inside = isInsideDropZone(e);
      const cards = document.querySelectorAll("[data-upload-card]");

      if (inside) {
        e.dataTransfer.dropEffect = "copy";
        cards.forEach((card) => {
          if (!card.classList.contains("drag-active")) {
            showOrphScreenDrag(card);
          }
          if (!card.classList.contains("drag-target")) {
            enterDropZoneTarget(card);
          }
        });
      } else {
        e.dataTransfer.dropEffect = "none";
        cards.forEach((card) => {
          if (!card.classList.contains("drag-active")) {
            showOrphScreenDrag(card);
          }
          if (card.classList.contains("drag-target")) {
            leaveDropZoneTarget(card);
          }
        });
      }
    });

    window.addEventListener("dragleave", (e) => {
      if (!hasFiles(e)) return;
      dragCounter--;
      if (
        dragCounter <= 0 ||
        e.clientX <= 0 ||
        e.clientY <= 0 ||
        e.clientX >= window.innerWidth ||
        e.clientY >= window.innerHeight
      ) {
        dragCounter = 0;
        document.querySelectorAll("[data-upload-card]").forEach((card) => {
          deactivateOrphScreenDrag(card);
        });
      }
    });

    window.addEventListener("drop", (e) => {
      if (!hasFiles(e)) return;
      e.preventDefault();
      dragCounter = 0;

      const inside = isInsideDropZone(e);
      const cards = document.querySelectorAll("[data-upload-card]");

      if (!inside) {
        cards.forEach((card) => {
          deactivateOrphScreenDrag(card);
        });
        return;
      }

      // Dropped inside: proceed with Orph file suction
      cards.forEach((card) => {
        card.classList.remove("drag-active", "drag-target");
      });

      const files = e.dataTransfer.files;
      if (files && files.length > 0) {
        const dropX = e.clientX || window.innerWidth / 2;
        const dropY = e.clientY || window.innerHeight / 2;
        executeDropWithOrph(files, dropX, dropY);
      }
    });
  }

  function formatBytes(bytes) {
    if (!bytes || bytes === 0) return "0 Bytes";
    const k = 1024;
    const sizes = ["Bytes", "KB", "MB", "GB"];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + " " + sizes[i];
  }

  function escapeHtml(str) {
    const div = document.createElement("div");
    div.textContent = str;
    return div.innerHTML;
  }

  function renderPendingUploadTiles(files) {
    if (!files || files.length === 0) return;

    // Ensure session cache is preserved so redirects never trigger full skeleton!
    try {
      sessionStorage.setItem(CACHE_KEY, "true");
    } catch (_) {}

    // Find the real timeline container
    let realTimeline = document.querySelector(".uploads-real-timeline");
    const timelineWrapper = document.querySelector("[data-timeline-wrapper]");
    let timeline = document.querySelector(".uploads-real-timeline .uploads-timeline");

    // If empty state was shown instead of real timeline:
    if (!realTimeline && timelineWrapper) {
      const emptyState = timelineWrapper.querySelector(".blankslate");
      if (emptyState) emptyState.style.display = "none";

      realTimeline = document.createElement("div");
      realTimeline.className = "uploads-real-timeline";
      realTimeline.innerHTML = '<div class="uploads-timeline" style="margin-top: 0;"></div>';
      timelineWrapper.appendChild(realTimeline);
      timeline = realTimeline.querySelector(".uploads-timeline");
    }

    if (!timeline) return;

    // Get today's ISO date string: YYYY-MM-DD
    const now = new Date();
    const year = now.getFullYear();
    const month = String(now.getMonth() + 1).padStart(2, "0");
    const day = String(now.getDate()).padStart(2, "0");
    const todayKey = `${year}-${month}-${day}`;

    const monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    const formattedDate = `${monthNames[now.getMonth()]} ${now.getDate()}, ${year}`;

    let todayGroup = document.getElementById("date-group-" + todayKey);
    let box = null;

    if (!todayGroup) {
      // Create Today group at the very top of timeline
      todayGroup = document.createElement("div");
      todayGroup.className = "timeline-date-group";
      todayGroup.id = "date-group-" + todayKey;
      todayGroup.setAttribute("data-date-group", todayKey);
      todayGroup.innerHTML = `
        <div class="timeline-date-header">
          <span class="timeline-node-icon">
            <svg class="octicon octicon-git-commit" viewBox="0 0 16 16" width="16" height="16" fill="currentColor">
              <path d="M11.93 8.5a4.002 4.002 0 0 1-7.86 0H.75a.75.75 0 0 1 0-1.5h3.32a4.002 4.002 0 0 1 7.86 0h3.32a.75.75 0 0 1 0 1.5Zm-1.43-.75a2.5 2.5 0 1 0-5 0 2.5 2.5 0 0 0 5 0Z"></path>
            </svg>
          </span>
          <h3 class="timeline-date-title">
            Today <span style="color: var(--fgColor-muted, #656d76); font-weight: 400; font-size: 13px;">— ${formattedDate}</span>
          </h3>
          <span class="Label Label--secondary" data-pending-count="true">${files.length} ${files.length === 1 ? "file" : "files"}</span>
        </div>
        <div class="Box"></div>
      `;
      timeline.insertBefore(todayGroup, timeline.firstChild);
      box = todayGroup.querySelector(".Box");
    } else {
      box = todayGroup.querySelector(".Box");
      const countBadge = todayGroup.querySelector(".timeline-date-header .Label--secondary");
      if (countBadge) {
        const currentCount = parseInt(countBadge.textContent, 10) || 0;
        const newCount = currentCount + files.length;
        countBadge.textContent = `${newCount} ${newCount === 1 ? "file" : "files"}`;
      }
    }

    if (!box) return;

    // Prepend pending skeleton row for each uploading file
    Array.from(files).forEach((file) => {
      const row = document.createElement("div");
      row.className = "Box-row upload-row-item is-pending-upload";
      row.style.display = "flex";
      row.style.alignItems = "flex-start";
      row.style.gap = "12px";
      row.style.animation = "fade-slide-in 320ms cubic-bezier(0.16, 1, 0.3, 1) both";

      const name = escapeHtml(file.name || "Uploading file...");
      const sizeStr = formatBytes(file.size);

      row.setAttribute("data-pending-filename", file.name || "");
      row.innerHTML = `
        <input type="checkbox" disabled style="margin-top: 6px; opacity: 0.4; cursor: not-allowed;">
        <div style="flex: 1; min-width: 0;">
          <div style="display: flex; justify-content: space-between; align-items: flex-start; gap: 16px;">
            <div style="flex: 1; min-width: 0;">
              <div style="display: flex; align-items: center; gap: 8px; margin-bottom: 6px; min-width: 0; max-width: 100%;">
                <span style="color: var(--fgColor-muted, #656d76); flex-shrink: 0; display: inline-flex; align-items: center;">
                  <svg class="octicon octicon-file" viewBox="0 0 16 16" width="16" height="16" fill="currentColor">
                    <path d="M2 1.75C2 .784 2.784 0 3.75 0h6.586c.464 0 .909.184 1.237.513l2.914 2.914c.329.328.513.773.513 1.237v9.586A1.75 1.75 0 0 1 13.25 16h-9.5A1.75 1.75 0 0 1 2 14.25Zm1.75-.25a.25.25 0 0 0-.25.25v12.5c0 .138.112.25.25.25h9.5a.25.25 0 0 0 .25-.25V6h-2.75A1.75 1.75 0 0 1 9 4.25V1.5Zm6.75.062V4.25c0 .138.112.25.25.25h2.688l-.011-.013-2.914-2.914-.013-.011Z"></path>
                  </svg>
                </span>
                <span class="upload-title-text" style="font-weight: 500; font-size: 14px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; max-width: 65%;">${name}</span>
                <span class="Label Label--accent" style="flex-shrink: 0; font-size: 11px;">Uploading...</span>
              </div>
              <div class="upload-meta-text" style="font-size: 12px; display: flex; align-items: center; gap: 8px;">
                <span>${sizeStr}</span>
                <span>•</span>
                <span class="skeleton-pill" style="display: inline-block; width: 64px; height: 10px; border-radius: 3px;"></span>
              </div>
            </div>
            <div class="upload-row-actions" style="display: flex; gap: 8px; align-items: center; flex-shrink: 0;">
              <div class="skeleton-pill" style="width: 28px; height: 28px; border-radius: 6px;"></div>
              <div class="skeleton-pill" style="width: 28px; height: 28px; border-radius: 6px;"></div>
              <div class="skeleton-pill" style="width: 28px; height: 28px; border-radius: 6px;"></div>
            </div>
          </div>
        </div>
      `;

      if (box.firstChild) {
        box.insertBefore(row, box.firstChild);
      } else {
        box.appendChild(row);
      }
    });
  }

  function finalizePendingUploadTiles(uploads) {
    if (!uploads || uploads.length === 0) return;

    uploads.forEach((u) => {
      let pendingRow = null;
      if (u.filename) {
        pendingRow = document.querySelector(`.is-pending-upload[data-pending-filename="${CSS.escape(u.filename)}"]`);
      }
      if (!pendingRow) {
        pendingRow = document.querySelector(".is-pending-upload");
      }

      if (pendingRow) {
        pendingRow.classList.remove("is-pending-upload");
        pendingRow.removeAttribute("data-pending-filename");
        pendingRow.setAttribute("data-upload-row-id", u.id);
        pendingRow.style.animation = "fade-slide-in 320ms cubic-bezier(0.16, 1, 0.3, 1) both";

        const now = new Date();
        const year = now.getFullYear();
        const month = String(now.getMonth() + 1).padStart(2, "0");
        const day = String(now.getDate()).padStart(2, "0");
        const todayKey = `${year}-${month}-${day}`;
        const monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        const formattedDate = `${monthNames[now.getMonth()]} ${now.getDate()}, ${year}`;

        pendingRow.innerHTML = `
          <input
            type="checkbox"
            name="ids[]"
            value="${escapeHtml(u.id)}"
            form="batch-delete-form"
            data-batch-select-item="true"
            data-upload-id="${escapeHtml(u.id)}"
            data-created-at="${todayKey}"
            data-formatted-date="${formattedDate}"
            style="margin-top: 6px; cursor: pointer;"
          >
          <div style="flex: 1; min-width: 0;">
            ${u.row_html}
          </div>
        `;
      }
    });
  }

  function removePendingUploadTiles(files) {
    if (!files) return;
    Array.from(files).forEach((file) => {
      let pendingRow = null;
      if (file.name) {
        pendingRow = document.querySelector(`.is-pending-upload[data-pending-filename="${CSS.escape(file.name)}"]`);
      }
      if (!pendingRow) {
        pendingRow = document.querySelector(".is-pending-upload");
      }
      if (pendingRow) {
        pendingRow.remove();
      }
    });
  }

  function showSuccessToast(message) {
    if (toastEl) toastEl.remove();

    const formattedMessage = formatToastMessage(message);

    toastEl = document.createElement("div");
    toastEl.className = "upload-status-toast upload-status-toast--success";
    toastEl.innerHTML = `
      <svg class="octicon octicon-check" viewBox="0 0 16 16" width="16" height="16" fill="var(--fgColor-success, #2da44e)">
        <path d="M13.78 4.22a.75.75 0 0 1 0 1.06l-7.25 7.25a.75.75 0 0 1-1.06 0L2.22 9.28a.751.751 0 0 1 .018-1.042.751.751 0 0 1 1.042-.018L6 10.94l6.72-6.72a.75.75 0 0 1 1.06 0Z"></path>
      </svg>
      <span class="upload-toast-text">${escapeHtml(formattedMessage)}</span>
    `;
    document.body.appendChild(toastEl);

    setTimeout(() => {
      if (toastEl && toastEl.classList.contains("upload-status-toast--success")) {
        toastEl.style.transition = "opacity 300ms ease, transform 300ms ease";
        toastEl.style.opacity = "0";
        toastEl.style.transform = "translateY(12px) scale(0.96)";
        setTimeout(() => {
          if (toastEl) {
            toastEl.remove();
            toastEl = null;
          }
        }, 300);
      }
    }, 3200);
  }

  function showErrorToast(message) {
    if (toastEl) toastEl.remove();

    const formattedMessage = formatToastMessage(message);

    toastEl = document.createElement("div");
    toastEl.className = "upload-status-toast upload-status-toast--danger";
    toastEl.innerHTML = `
      <svg class="octicon octicon-alert" viewBox="0 0 16 16" width="16" height="16" fill="var(--fgColor-danger, #cf222e)">
        <path d="M6.457 1.047c.659-1.234 2.427-1.234 3.086 0l6.082 11.378A1.75 1.75 0 0 1 14.082 15H1.918a1.75 1.75 0 0 1-1.543-2.575Zm1.763.707a.25.25 0 0 0-.44 0L1.698 13.132a.25.25 0 0 0 .22.368h12.164a.25.25 0 0 0 .22-.368Zm.53 3.996v2.5a.75.75 0 0 1-1.5 0v-2.5a.75.75 0 0 1 1.5 0ZM9 11a1 1 0 1 1-2 0 1 1 0 0 1 2 0Z"></path>
      </svg>
      <span class="upload-toast-text">${escapeHtml(formattedMessage)}</span>
    `;
    document.body.appendChild(toastEl);

    setTimeout(() => {
      if (toastEl && toastEl.classList.contains("upload-status-toast--danger")) {
        toastEl.remove();
        toastEl = null;
      }
    }, 4500);
  }

  function updateActivityRibbonOnUpload(addedCount) {
    const now = new Date();
    const todayKey = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-${String(now.getDate()).padStart(2, "0")}`;
    const todayCell = document.querySelector(`.activity-cell[data-date="${todayKey}"]`);
    if (!todayCell) return;

    let currentUploads = 0;
    const countStr = todayCell.getAttribute("data-tooltip-count") || "";
    const match = countStr.match(/(\d+)/);
    if (match) {
      currentUploads = parseInt(match[1], 10);
    }
    const newCount = currentUploads + addedCount;

    let newLevel = 1;
    if (newCount === 0) newLevel = 0;
    else if (newCount <= 2) newLevel = 1;
    else if (newCount <= 5) newLevel = 2;
    else if (newCount <= 9) newLevel = 3;
    else newLevel = 4;

    const countText = `${newCount} ${newCount === 1 ? "upload" : "uploads"}`;
    const dateText = todayCell.getAttribute("data-tooltip-date") || "";

    todayCell.setAttribute("data-level", newLevel);
    todayCell.setAttribute("data-has-uploads", "true");
    todayCell.setAttribute("data-tooltip-count", countText);
    todayCell.setAttribute("aria-label", `${countText} ${dateText}`.trim());
  }

  function updateTotalUploadCountBadge(addedCount) {
    const historyHeader = document.querySelector("[data-uploads-history]");
    const badge = document.querySelector("[data-uploads-total-count]") || (historyHeader ? historyHeader.nextElementSibling : null);
    if (badge) {
      const countMatch = badge.textContent.match(/(\d+)/);
      if (countMatch) {
        const currentTotal = parseInt(countMatch[1], 10);
        const newTotal = Math.max(0, currentTotal + addedCount);
        badge.textContent = `${newTotal} ${newTotal === 1 ? "file" : "files"}`;
      }
    }
  }

  function animateAndRemoveRow(rowEl, onComplete) {
    if (!rowEl) {
      if (onComplete) onComplete();
      return;
    }
    const currentHeight = rowEl.scrollHeight;
    rowEl.style.maxHeight = currentHeight + "px";
    void rowEl.offsetHeight; // force reflow
    rowEl.classList.add("is-deleting");

    setTimeout(() => {
      rowEl.remove();
      if (onComplete) onComplete();
    }, 260);
  }

  function handleRowDeletionUpdates(deletedUploadIds) {
    if (!deletedUploadIds || deletedUploadIds.length === 0) return;

    const stringIds = deletedUploadIds.map((id) => String(id));
    const affectedDateGroups = new Set();

    stringIds.forEach((id) => {
      const rowItem =
        document.querySelector(`.upload-row-item[data-upload-row-id="${id}"]`) ||
        document.querySelector(`[data-batch-select-item][data-upload-id="${id}"]`)?.closest(".upload-row-item") ||
        document.querySelector(`[data-batch-select-item][data-upload-id="${id}"]`)?.closest(".Box-row");

      if (rowItem) {
        const dateGroup = rowItem.closest(".timeline-date-group");
        if (dateGroup) affectedDateGroups.add(dateGroup);
        const containerRow = rowItem.closest(".Box-row") || rowItem;
        animateAndRemoveRow(containerRow);
      }

      const cb = document.querySelector(`[data-batch-select-item][data-upload-id="${id}"]`);
      if (cb) cb.checked = false;
    });

    if (typeof window.updateBatchBar === "function") {
      window.updateBatchBar();
    }

    updateTotalUploadCountBadge(-stringIds.length);

    setTimeout(() => {
      affectedDateGroups.forEach((group) => {
        const remainingRows = group.querySelectorAll(".upload-row-item:not(.is-deleting)");
        const countBadge = group.querySelector("[data-date-group-count]") || group.querySelector(".timeline-date-header .Label, .timeline-date-header .Label--secondary");
        if (remainingRows.length === 0) {
          group.style.transition = "opacity 200ms ease, transform 200ms ease";
          group.style.opacity = "0";
          setTimeout(() => group.remove(), 200);
        } else if (countBadge) {
          countBadge.textContent = `${remainingRows.length} ${remainingRows.length === 1 ? "file" : "files"}`;
        }
      });
    }, 280);

    refreshRibbonInBackground();
  }

  function bindSingleDeleteForms() {
    document.addEventListener("submit", (e) => {
      const form = e.target.closest("[data-delete-upload-form]");
      if (!form) return;

      e.preventDefault();

      const uploadId = form.getAttribute("data-upload-id");
      const filename = form.getAttribute("data-upload-filename") || "file";
      const actionUrl = form.getAttribute("action");

      // Close the parent confirmation dialog immediately
      const dialog = form.closest("dialog");
      if (dialog && typeof dialog.close === "function") {
        dialog.close();
      } else {
        const cancelBtn = form.closest("div")?.querySelector("[data-close-dialog-id]");
        if (cancelBtn) cancelBtn.click();
      }

      const csrfToken =
        document.querySelector('meta[name="csrf-token"]')?.content ||
        form.querySelector('input[name="authenticity_token"]')?.value ||
        "";

      const formData = new FormData(form);
      formData.append("_method", "delete");

      fetch(actionUrl, {
        method: "POST",
        body: formData,
        headers: {
          "Accept": "application/json",
          "X-Requested-With": "XMLHttpRequest",
          ...(csrfToken ? { "X-CSRF-Token": csrfToken } : {})
        }
      })
        .then(async (response) => {
          let data = null;
          try {
            data = await response.json();
          } catch (_) {}

          if (!response.ok || !data || !data.success) {
            const errorMsg = (data && data.error) ? data.error : `Delete failed (status ${response.status})`;
            throw new Error(errorMsg);
          }
          return data;
        })
        .then((data) => {
          handleRowDeletionUpdates([uploadId || data.id]);
          showSuccessToast(data.notice || `Deleted "${filename}" successfully.`);
        })
        .catch((err) => {
          console.error("Delete error:", err);
          showErrorToast(err.message || "Failed to delete file.");
        });
    });
  }

  window.CDNToast = window.CDNToast || {};
  window.CDNToast.showSuccess = showSuccessToast;
  window.CDNToast.showError = showErrorToast;
  window.CDNToast.refreshRibbon = refreshRibbonInBackground;
  window.CDNToast.truncateMiddle = truncateMiddle;
  window.CDNToast.handleRowDeletionUpdates = handleRowDeletionUpdates;

  function directUpload(files) {
    if (!files || files.length === 0) return;
    try {
      sessionStorage.setItem(CACHE_KEY, "true");
    } catch (_) {}

    // Show scoped pending skeleton tile(s) for the new files
    renderPendingUploadTiles(files);
    showUploadToast(files.length);

    const formData = new FormData();
    for (let i = 0; i < files.length; i++) {
      formData.append("files[]", files[i]);
    }

    const csrfToken =
      document.querySelector('meta[name="csrf-token"]')?.content ||
      (form ? form.querySelector('input[name="authenticity_token"]')?.value : "") ||
      "";

    if (csrfToken) {
      formData.append("authenticity_token", csrfToken);
    }

    const uploadUrl = (form && form.action) ? form.action : "/uploads";

    fetch(uploadUrl, {
      method: "POST",
      body: formData,
      headers: {
        "Accept": "application/json",
        "X-Requested-With": "XMLHttpRequest",
        ...(csrfToken ? { "X-CSRF-Token": csrfToken } : {})
      }
    })
      .then(async (response) => {
        let data = null;
        try {
          data = await response.json();
        } catch (_) {}

        if (!response.ok || !data || !data.success) {
          const errorMsg = (data && data.error) ? data.error : `Upload failed (status ${response.status})`;
          throw new Error(errorMsg);
        }
        return data;
      })
      .then((data) => {
        finalizePendingUploadTiles(data.uploads);
        showSuccessToast(data.notice || `Uploaded ${files.length} ${files.length === 1 ? "file" : "files"} successfully!`);
        updateActivityRibbonOnUpload(data.uploads.length);
        updateTotalUploadCountBadge(data.uploads.length);
        refreshRibbonInBackground();
      })
      .catch((err) => {
        console.error("Direct upload error:", err);
        removePendingUploadTiles(files);
        showErrorToast(err.message || "Upload failed. Please try again.");
      });
  }

  function bindPasteEvents() {
    window.addEventListener("paste", (e) => {
      const activeTag = document.activeElement ? document.activeElement.tagName.toLowerCase() : "";
      if (
        activeTag === "input" ||
        activeTag === "textarea" ||
        (document.activeElement && document.activeElement.isContentEditable)
      ) {
        return;
      }

      if (!e.clipboardData || !e.clipboardData.files || e.clipboardData.files.length === 0) {
        return;
      }

      const files = e.clipboardData.files;
      if (files.length > 0) {
        e.preventDefault();
        directUpload(files);
      }
    });
  }

  // Tumble files into Orph mouth on drop
  function executeDropWithOrph(files, dropX, dropY) {
    if (!form || !fileInput || isDropping) return;
    isDropping = true;

    const cards = document.querySelectorAll("[data-upload-card]");
    cards.forEach((c) => {
      c.classList.remove("drag-active", "drag-target");
      c.classList.add("is-dropping");
    });

    const card = document.querySelector("[data-upload-card]");
    const orphStage = card ? card.querySelector("[data-orph-stage]") : null;
    const bubble = card ? card.querySelector("[data-orph-bubble]") : null;

    // Small screens (<= 768px): instant submission without suction animation
    if (window.innerWidth <= 768 || !orphStage) {
      cards.forEach((c) => c.classList.remove("is-dropping"));
      directUpload(files);
      isDropping = false;
      return;
    }

    // Snap mouth open and update bubble
    orphStage.classList.add("mouth-open");
    orphStage.classList.remove("gulping");
    if (bubble) bubble.textContent = "Feed me files!";

    playDesktopDropEffect(files, dropX, dropY, () => {
      // Once file icons reach mouth: gulp!
      orphStage.classList.remove("mouth-open");
      orphStage.classList.add("gulping");
      if (bubble) bubble.textContent = "Gulp! Uploading...";

      setTimeout(() => {
        orphStage.classList.remove("gulping");
        directUpload(files);
        cards.forEach((c) => c.classList.remove("is-dropping"));
        isDropping = false;
      }, 650);
    });
  }

  // Drop tumble animation into Orph mouth
  function playDesktopDropEffect(files, dropX, dropY, onComplete) {
    const card = document.querySelector("[data-upload-card]");
    const orphStage = card ? card.querySelector("[data-orph-stage]") : null;
    const charEl = card ? card.querySelector("[data-orph-character]") : null;

    if (!orphStage) {
      onComplete();
      return;
    }

    const targetRect = (charEl && charEl.getBoundingClientRect().width > 0)
      ? charEl.getBoundingClientRect()
      : orphStage.getBoundingClientRect();

    // Calibrated mouth coordinates in orph-open-mouth.svg
    const mouthX = targetRect.left + targetRect.width * 0.6305;
    const mouthY = targetRect.top + targetRect.height * 0.2896;

    const fileList = Array.from(files);
    const displayCount = Math.min(Math.max(fileList.length, 1), 8);
    let finishedCount = 0;

    const iconWidth = Math.max(26, Math.round(targetRect.width * 0.2));
    const iconHeight = Math.round(iconWidth * 1.2);

    for (let i = 0; i < displayCount; i++) {
      const fileIcon = document.createElement("div");
      fileIcon.className = "orph-sucked-file";
      fileIcon.style.width = `${iconWidth}px`;
      fileIcon.style.height = `${iconHeight}px`;
      fileIcon.innerHTML = `<img src="/file-icon.svg" alt="file" draggable="false">`;

      document.body.appendChild(fileIcon);

      const spreadAngle = (i / displayCount) * Math.PI * 2;
      const spreadRadius = displayCount > 1 ? 10 + (i % 3) * 8 : 0;
      const startX = dropX + Math.cos(spreadAngle) * spreadRadius;
      const startY = dropY + Math.sin(spreadAngle) * spreadRadius;

      const dx = mouthX - startX;
      const dy = mouthY - startY;

      const frames = [];
      const steps = 30;
      const spinDirection = i % 2 === 0 ? 1 : -1;
      const totalRotation = spinDirection * 360;

      for (let s = 0; s <= steps; s++) {
        const t = s / steps;
        const posX = startX + dx * t;
        const posY = startY + dy * t;
        const rotation = (totalRotation * t).toFixed(1);
        const scale = Math.max(0, 1 - Math.pow(t, 1.3));
        const opacity = t > 0.94 ? Math.max(0, (1 - t) / 0.06) : 1;

        frames.push({
          transform: `translate3d(${posX.toFixed(1)}px, ${posY.toFixed(1)}px, 0) translate(-50%, -50%) scale(${scale.toFixed(3)}) rotate(${rotation}deg)`,
          opacity: opacity
        });
      }

      const duration = 850;
      const delay = i * 60;

      const animation = fileIcon.animate(frames, {
        duration: duration,
        delay: delay,
        easing: "linear",
        fill: "forwards"
      });

      animation.onfinish = () => {
        fileIcon.remove();
        finishedCount++;
        if (finishedCount === displayCount) {
          onComplete();
        }
      };
    }
  }

  // Orph eye tracking during drag over drop zone
  function bindOrphCompanion() {
    const card = document.querySelector("[data-upload-card]");
    if (!card) return;

    const orphStage = card.querySelector("[data-orph-stage]");
    const charEl = card.querySelector("[data-orph-character]");
    const leftPupil = card.querySelector("[data-orph-pupil-left]");
    const rightPupil = card.querySelector("[data-orph-pupil-right]");
    const orphView = card.querySelector("[data-orph-view]");

    if (!orphStage) return;

    let eyeRafId = null;

    // Allow clicking the Orph drop card view to open file picker
    if (orphView) {
      orphView.style.cursor = "pointer";
      orphView.addEventListener("click", () => {
        if (isDropping) return;
        if (fileInput) fileInput.click();
      });
    }

    function updateEyeTracking(mouseX, mouseY) {
      if (!orphStage || !leftPupil || !rightPupil) return;

      const rect = (charEl && charEl.getBoundingClientRect().width > 0)
        ? charEl.getBoundingClientRect()
        : orphStage.getBoundingClientRect();

      if (!rect || rect.width === 0) return;

      // Calibrated eye base centers inside Orph character
      const leftEyeBaseX = rect.left + rect.width * 0.534;
      const leftEyeBaseY = rect.top + rect.height * 0.128;
      const rightEyeBaseX = rect.left + rect.width * 0.688;
      const rightEyeBaseY = rect.top + rect.height * 0.087;

      // Strict elliptical boundary limits in pixels
      const leftMaxX = rect.width * 0.015;
      const leftMaxY = rect.height * 0.007;

      const rightMaxX = rect.width * 0.013;
      const rightMaxY = rect.height * 0.006;

      const rawLx = (mouseX - leftEyeBaseX) * 0.035;
      const rawLy = (mouseY - leftEyeBaseY) * 0.035;
      const scaleL = Math.max(1, Math.hypot(rawLx / leftMaxX, rawLy / leftMaxY));
      const offLx = rawLx / scaleL;
      const offLy = rawLy / scaleL;

      const rawRx = (mouseX - rightEyeBaseX) * 0.035;
      const rawRy = (mouseY - rightEyeBaseY) * 0.035;
      const scaleR = Math.max(1, Math.hypot(rawRx / rightMaxX, rawRy / rightMaxY));
      const offRx = rawRx / scaleR;
      const offRy = rawRy / scaleR;

      leftPupil.style.transform = `translate(-50%, -50%) translate3d(${offLx.toFixed(2)}px, ${offLy.toFixed(2)}px, 0)`;
      rightPupil.style.transform = `translate(-50%, -50%) translate3d(${offRx.toFixed(2)}px, ${offRy.toFixed(2)}px, 0)`;
    }

    window.addEventListener("dragover", (e) => {
      if (window.innerWidth <= 768) return;
      if (!card.classList.contains("drag-active") && !card.classList.contains("drag-target") && !card.classList.contains("is-dropping")) return;
      if (!eyeRafId) {
        eyeRafId = requestAnimationFrame(() => {
          eyeRafId = null;
          updateEyeTracking(e.clientX, e.clientY);
        });
      }
    });
  }

  // Activity ribbon tooltip
  function ensureTooltip() {
    if (tooltip && document.body.contains(tooltip)) return tooltip;
    tooltip = document.createElement("div");
    tooltip.className = "primer-activity-tooltip";
    tooltip.setAttribute("role", "tooltip");
    document.body.appendChild(tooltip);
    return tooltip;
  }

  function bindActivityTooltipEvents() {
    document.addEventListener("mouseover", (e) => {
      const cell = e.target.closest(".activity-cell");
      if (!cell) return;

      const count = cell.getAttribute("data-tooltip-count") || "No uploads";
      const date = cell.getAttribute("data-tooltip-date") || "";
      const tip = ensureTooltip();

      tip.innerHTML = `<strong>${count}</strong> ${date}`;
      tip.classList.add("is-visible");

      const rect = cell.getBoundingClientRect();
      const tipRect = tip.getBoundingClientRect();

      let targetLeft = rect.left + rect.width / 2;
      let caretLeftPercent = 50;

      const pad = 12;
      const minLeft = tipRect.width / 2 + pad;
      const maxLeft = window.innerWidth - tipRect.width / 2 - pad;

      if (targetLeft < minLeft) {
        const diff = minLeft - targetLeft;
        targetLeft = minLeft;
        caretLeftPercent = 50 - (diff / tipRect.width) * 100;
      } else if (targetLeft > maxLeft) {
        const diff = targetLeft - maxLeft;
        targetLeft = maxLeft;
        caretLeftPercent = 50 + (diff / tipRect.width) * 100;
      }

      tip.style.setProperty("--caret-left", `${Math.max(15, Math.min(85, caretLeftPercent))}%`);
      tip.style.left = `${targetLeft}px`;
      tip.style.top = `${rect.top - tipRect.height - 7}px`;
    });

    document.addEventListener("mouseout", (e) => {
      const cell = e.target.closest(".activity-cell");
      if (!cell || !tooltip) return;
      if (e.relatedTarget && e.relatedTarget.closest && e.relatedTarget.closest(".activity-cell")) {
        return;
      }
      tooltip.classList.remove("is-visible");
    });
  }

  let activeHighlightGroup = null;
  let highlightObserver = null;
  let disappearTimer = null;
  let fadeCleanupTimer = null;
  let removeInterferenceListeners = null;

  function clearActiveHighlight() {
    if (disappearTimer) {
      clearTimeout(disappearTimer);
      disappearTimer = null;
    }
    if (fadeCleanupTimer) {
      clearTimeout(fadeCleanupTimer);
      fadeCleanupTimer = null;
    }
    if (highlightObserver) {
      highlightObserver.disconnect();
      highlightObserver = null;
    }
    if (removeInterferenceListeners) {
      removeInterferenceListeners();
      removeInterferenceListeners = null;
    }
    if (activeHighlightGroup) {
      activeHighlightGroup.classList.remove("is-highlighted", "is-fading-out");
      activeHighlightGroup = null;
    }
  }

  function startDisappearTimer(group, delayMs) {
    if (disappearTimer) clearTimeout(disappearTimer);
    if (fadeCleanupTimer) clearTimeout(fadeCleanupTimer);

    disappearTimer = setTimeout(() => {
      if (group && document.body.contains(group)) {
        group.classList.add("is-fading-out");
        fadeCleanupTimer = setTimeout(() => {
          group.classList.remove("is-highlighted", "is-fading-out");
          if (activeHighlightGroup === group) {
            activeHighlightGroup = null;
          }
        }, 1200);
      }
    }, delayMs);
  }

  function isElementInViewport(el) {
    const rect = el.getBoundingClientRect();
    const vh = window.innerHeight || document.documentElement.clientHeight;
    const vw = window.innerWidth || document.documentElement.clientWidth;
    return (
      rect.top < vh &&
      rect.bottom > 0 &&
      rect.left < vw &&
      rect.right > 0
    );
  }

  function bindActivityClickScrollEvents() {
    document.addEventListener("click", (e) => {
      const cell = e.target.closest(".activity-cell");
      if (!cell) return;

      // Clicking empty activity in the graph does nothing
      const level = cell.getAttribute("data-level");
      const hasUploads = cell.getAttribute("data-has-uploads");
      if (level === "0" || hasUploads === "false") return;

      const dateStr = cell.getAttribute("data-date");
      if (!dateStr) return;

      const targetGroup = document.getElementById("date-group-" + dateStr);
      if (!targetGroup) return;

      // Clear any prior highlight state cleanly
      clearActiveHighlight();

      activeHighlightGroup = targetGroup;
      targetGroup.classList.remove("is-fading-out");
      void targetGroup.offsetWidth;
      targetGroup.classList.add("is-highlighted");

      // Smoothly scroll down to the date section
      targetGroup.scrollIntoView({ behavior: "smooth", block: "center" });

      // If already within viewport, start disappear timer now
      if (isElementInViewport(targetGroup)) {
        startDisappearTimer(targetGroup, 1500);
        return;
      }

      // Otherwise, keep highlighting until it reaches the viewport OR user interferes
      let reachedViewport = false;

      function onArrival() {
        if (reachedViewport) return;
        reachedViewport = true;

        if (highlightObserver) {
          highlightObserver.disconnect();
          highlightObserver = null;
        }
        if (removeInterferenceListeners) {
          removeInterferenceListeners();
          removeInterferenceListeners = null;
        }

        startDisappearTimer(targetGroup, 1500);
      }

      if (window.IntersectionObserver) {
        highlightObserver = new IntersectionObserver((entries) => {
          for (const entry of entries) {
            if (entry.isIntersecting && entry.intersectionRatio > 0.05) {
              onArrival();
              break;
            }
          }
        }, {
          threshold: [0.05, 0.2, 0.5]
        });
        highlightObserver.observe(targetGroup);
      } else {
        startDisappearTimer(targetGroup, 2500);
      }

      function onUserInterference(evt) {
        if (evt && evt.target && evt.target.closest && evt.target.closest(".activity-cell")) {
          return;
        }
        if (reachedViewport) return;
        reachedViewport = true;

        if (highlightObserver) {
          highlightObserver.disconnect();
          highlightObserver = null;
        }
        if (removeInterferenceListeners) {
          removeInterferenceListeners();
          removeInterferenceListeners = null;
        }

        // Start disappear timer immediately!
        startDisappearTimer(targetGroup, 300);
      }

      const scrollKeyCodes = ["ArrowDown", "ArrowUp", "PageDown", "PageUp", "Home", "End", " "];
      function onKeydown(evt) {
        if (scrollKeyCodes.includes(evt.key)) {
          onUserInterference(evt);
        }
      }

      const bindTimer = setTimeout(() => {
        window.addEventListener("wheel", onUserInterference, { passive: true, capture: true });
        window.addEventListener("touchmove", onUserInterference, { passive: true, capture: true });
        window.addEventListener("touchstart", onUserInterference, { passive: true, capture: true });
        window.addEventListener("keydown", onKeydown, { passive: true, capture: true });
      }, 80);

      removeInterferenceListeners = () => {
        clearTimeout(bindTimer);
        window.removeEventListener("wheel", onUserInterference, { capture: true });
        window.removeEventListener("touchmove", onUserInterference, { capture: true });
        window.removeEventListener("touchstart", onUserInterference, { capture: true });
        window.removeEventListener("keydown", onKeydown, { capture: true });
      };
    });

    document.addEventListener("keydown", (e) => {
      if (e.key === "Enter" || e.key === " ") {
        const cell = document.activeElement && document.activeElement.classList.contains("activity-cell")
          ? document.activeElement
          : null;
        if (cell) {
          const level = cell.getAttribute("data-level");
          const hasUploads = cell.getAttribute("data-has-uploads");
          if (level === "0" || hasUploads === "false") return;

          e.preventDefault();
          cell.click();
        }
      }
    });
  }

  let ribbonResizeObserver = null;
  let lastRibbonWidth = 0;

  function adjustActivityRibbonColumns(force = false) {
    const ribbon = document.querySelector("[data-activity-ribbon]");
    if (!ribbon) return;

    const grid = ribbon.querySelector(".activity-grid");
    if (!grid) return;

    const columns = grid.querySelectorAll(".activity-column");
    if (columns.length === 0) return;

    const availableWidth = ribbon.clientWidth;
    if (availableWidth <= 0) return;
    if (!force && availableWidth === lastRibbonWidth) return;
    lastRibbonWidth = availableWidth;

    const colWidth = 10;
    const minGap = 3;
    const colStep = colWidth + minGap; // 13px

    // How many WHOLE 10px columns fit inside availableWidth without clipping:
    const maxCols = Math.max(1, Math.min(columns.length, Math.floor((availableWidth + minGap) / colStep)));

    // Newest column is at the end (columns.length - 1). Show only the rightmost `maxCols` columns:
    const startIndex = columns.length - maxCols;

    for (let i = 0; i < columns.length; i++) {
      columns[i].style.display = (i < startIndex) ? "none" : "flex";
    }

    grid.style.justifyContent = maxCols > 1 ? "space-between" : "flex-end";
  }

  function setupRibbonResizeObserver() {
    const ribbon = document.querySelector("[data-activity-ribbon]");
    if (!ribbon) return;

    if (ribbonResizeObserver) {
      ribbonResizeObserver.disconnect();
    }

    if (window.ResizeObserver) {
      ribbonResizeObserver = new ResizeObserver(() => {
        adjustActivityRibbonColumns();
      });
      ribbonResizeObserver.observe(ribbon);
    } else {
      window.addEventListener("resize", adjustActivityRibbonColumns);
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }

  document.addEventListener("turbo:load", init);
})();
