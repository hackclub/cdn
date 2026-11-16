// Upload dropzone and clipboard paste controller
(function () {
  let initialized = false;
  let eventsBound = false;
  let form = null;
  let fileInput = null;
  let dragCounter = 0;
  let toastEl = null;
  let isDropping = false;

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

  function hasFiles(e) {
    if (!e.dataTransfer) return false;
    const types = e.dataTransfer.types;
    if (!types) return false;
    for (let i = 0; i < types.length; i++) {
      if (types[i] === "Files") return true;
    }
    return false;
  }

  function isInsideDropZone(e) {
    const card = document.querySelector("[data-upload-card]");
    if (!card) return false;
    const rect = card.getBoundingClientRect();
    return (
      e.clientX >= rect.left &&
      e.clientX <= rect.right &&
      e.clientY >= rect.top &&
      e.clientY <= rect.bottom
    );
  }

  function showOrphScreenDrag(card) {
    card.classList.add("drag-active");
    card.classList.remove("drag-target");
    const orphStage = card.querySelector("[data-orph-stage]");
    if (orphStage) {
      orphStage.classList.remove("mouth-open");
    }
    const bubble = card.querySelector("[data-orph-bubble]");
    if (bubble && bubble.textContent !== "Feed me files!") {
      bubble.textContent = "Feed me files!";
    }
  }

  function enterDropZoneTarget(card) {
    card.classList.add("drag-target");
    const orphStage = card.querySelector("[data-orph-stage]");
    if (orphStage) {
      orphStage.classList.add("mouth-open");
    }
    const titleEl = card.querySelector("[data-dropzone-title]");
    if (titleEl && !titleEl.dataset.hasCustomTitle) {
      titleEl.textContent = getRandomTitle();
      titleEl.dataset.hasCustomTitle = "true";
    }
    const bubble = card.querySelector("[data-orph-bubble]");
    if (bubble) {
      bubble.textContent = "Drop them in!";
    }
  }

  function leaveDropZoneTarget(card) {
    card.classList.remove("drag-target");
    const orphStage = card.querySelector("[data-orph-stage]");
    if (orphStage) {
      orphStage.classList.remove("mouth-open");
    }
    const bubble = card.querySelector("[data-orph-bubble]");
    if (bubble) {
      bubble.textContent = "Feed me files!";
    }
  }

  function deactivateOrphScreenDrag(card) {
    card.classList.remove("drag-active", "drag-target");
    const orphStage = card.querySelector("[data-orph-stage]");
    if (orphStage) {
      orphStage.classList.remove("mouth-open");
    }
    const titleEl = card.querySelector("[data-dropzone-title]");
    if (titleEl) {
      titleEl.removeAttribute("data-has-custom-title");
    }
    const bubble = card.querySelector("[data-orph-bubble]");
    if (bubble) {
      bubble.textContent = "Feed me files!";
    }
  }

  function bindDragAndDropEvents() {
    window.addEventListener("dragenter", (e) => {
      if (!hasFiles(e)) return;
      dragCounter++;

      const cards = document.querySelectorAll("[data-upload-card]");
      cards.forEach((card) => {
        if (isInsideDropZone(e)) {
          showOrphScreenDrag(card);
          enterDropZoneTarget(card);
        } else {
          showOrphScreenDrag(card);
        }
      });
    });

    window.addEventListener("dragover", (e) => {
      if (!hasFiles(e)) return;
      e.preventDefault();

      const cards = document.querySelectorAll("[data-upload-card]");
      const inside = isInsideDropZone(e);

      cards.forEach((card) => {
        if (inside) {
          e.dataTransfer.dropEffect = "copy";
          if (!card.classList.contains("drag-target")) {
            enterDropZoneTarget(card);
          }
        } else {
          e.dataTransfer.dropEffect = "none";
          if (card.classList.contains("drag-target")) {
            leaveDropZoneTarget(card);
          }
        }
      });
    });

    window.addEventListener("dragleave", (e) => {
      if (!hasFiles(e)) return;
      dragCounter--;

      if (dragCounter <= 0) {
        dragCounter = 0;
        const cards = document.querySelectorAll("[data-upload-card]");
        cards.forEach((card) => deactivateOrphScreenDrag(card));
      }
    });

    window.addEventListener("drop", (e) => {
      if (!hasFiles(e)) return;
      e.preventDefault();

      const wasTarget = isInsideDropZone(e);
      dragCounter = 0;

      const cards = document.querySelectorAll("[data-upload-card]");
      cards.forEach((card) => {
        card.classList.remove("drag-active", "drag-target");
        const titleEl = card.querySelector("[data-dropzone-title]");
        if (titleEl) titleEl.removeAttribute("data-has-custom-title");
      });

      if (!wasTarget) return;

      const files = e.dataTransfer.files;
      if (files && files.length > 0) {
        executeDropWithOrph(files, e.clientX, e.clientY);
      }
    });
  }


  function showUploadToast(count) {
    if (!toastEl) {
      toastEl = document.createElement("div");
      toastEl.className = "upload-status-toast";
      toastEl.setAttribute("role", "status");
      toastEl.setAttribute("aria-live", "polite");
      document.body.appendChild(toastEl);
    }
    toastEl.innerHTML = `
      <span class="upload-toast-spinner"></span>
      <span>Uploading ${count} ${count === 1 ? "file" : "files"}...</span>
    `;
    toastEl.classList.remove("is-success", "is-error");
    toastEl.classList.add("is-visible");
  }

  function formatBytes(bytes) {
    if (!bytes || bytes === 0) return "0 B";
    const k = 1024;
    const sizes = ["B", "KB", "MB", "GB"];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return (bytes / Math.pow(k, i)).toFixed(i === 0 ? 0 : 1) + " " + sizes[i];
  }

  function escapeHtml(str) {
    return String(str || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;");
  }

  function renderPendingUploadTiles(files) {
    if (!files || files.length === 0) return;
    const timeline = document.querySelector(".uploads-timeline");
    if (!timeline) return;

    let todayGroup = timeline.querySelector('.timeline-date-group[data-date-group="today"]');
    if (!todayGroup) {
      todayGroup = document.createElement("div");
      todayGroup.className = "timeline-date-group";
      todayGroup.setAttribute("data-date-group", "today");
      todayGroup.innerHTML = `
        <div class="timeline-date-header timeline-item" style="--item-index: 1;">
          <span class="timeline-node-icon">
            <svg class="octicon octicon-git-commit" viewBox="0 0 16 16" width="16" height="16" fill="currentColor">
              <path d="M10.5 8a2.5 2.5 0 1 1-5 0 2.5 2.5 0 0 1 5 0Zm.002.75A3.998 3.998 0 0 0 14.25 9h.25a.75.75 0 0 0 0-1.5h-.25a3.998 3.998 0 0 0-3.748-2.75V3.25a.75.75 0 0 0-1.5 0v1.502A3.998 3.998 0 0 0 5.5 8.752V10.25a.75.75 0 0 0 1.5 0v-1.498A3.998 3.998 0 0 0 10.502 8.75Z"></path>
            </svg>
          </span>
          <h3 class="timeline-date-title">Today</h3>
          <span class="Label Label--secondary" data-date-count>Just now</span>
        </div>
        <div class="BorderBox"></div>
      `;
      if (timeline.firstChild) {
        timeline.insertBefore(todayGroup, timeline.firstChild);
      } else {
        timeline.appendChild(todayGroup);
      }
    }

    const box = todayGroup.querySelector(".BorderBox");
    if (!box) return;

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
        pendingRow.style.animation = "fade-slide-in 320ms cubic-bezier(0.16, 1, 0.3, 1) both";

        if (u.row_html) {
          pendingRow.outerHTML = `<div class="Box-row upload-row-item timeline-item" style="display: flex; align-items: flex-start; gap: 12px; animation: fade-slide-in 320ms cubic-bezier(0.16, 1, 0.3, 1) both;">
            <input type="checkbox" name="ids[]" value="${escapeHtml(u.id)}" form="batch-delete-form" data-batch-select-item="true" data-upload-id="${escapeHtml(u.id)}" style="margin-top: 6px; cursor: pointer;">
            <div style="flex: 1; min-width: 0;">${u.row_html}</div>
          </div>`;
        }
      }
    });
  }

  function removePendingUploadTiles() {
    const pending = document.querySelectorAll(".is-pending-upload");
    pending.forEach((el) => el.remove());
  }

  function showSuccessToast(message) {
    if (!toastEl) return;
    toastEl.innerHTML = `
      <svg class="octicon octicon-check" viewBox="0 0 16 16" width="16" height="16" fill="currentColor" style="color: var(--fgColor-success, #1a7f37);">
        <path d="M13.78 4.22a.75.75 0 0 1 0 1.06l-7.25 7.25a.75.75 0 0 1-1.06 0L2.22 9.28a.751.751 0 0 1 .018-1.042.751.751 0 0 1 1.042-.018L6 10.94l6.72-6.72a.75.75 0 0 1 1.06 0Z"></path>
      </svg>
      <span>${escapeHtml(message)}</span>
    `;
    toastEl.classList.add("is-success");
    setTimeout(() => {
      toastEl.classList.remove("is-visible", "is-success");
    }, 3500);
  }

  function showErrorToast(message) {
    if (!toastEl) return;
    toastEl.innerHTML = `
      <svg class="octicon octicon-alert" viewBox="0 0 16 16" width="16" height="16" fill="currentColor" style="color: var(--fgColor-danger, #cf222e);">
        <path d="M6.457 1.047c.659-1.234 2.427-1.234 3.086 0l6.082 11.378A1.75 1.75 0 0 1 14.082 15H1.918a1.75 1.75 0 0 1-1.543-2.575Zm1.763.707a.25.25 0 0 0-.44 0L1.698 13.132a.25.25 0 0 0 .22.368h12.164a.25.25 0 0 0 .22-.368Zm.53 3.996v2.5a.75.75 0 0 1-1.5 0v-2.5a.75.75 0 0 1 1.5 0ZM9 11a1 1 0 1 1-2 0 1 1 0 0 1 2 0Z"></path>
      </svg>
      <span>${escapeHtml(message)}</span>
    `;
    toastEl.classList.add("is-error");
    setTimeout(() => {
      toastEl.classList.remove("is-visible", "is-error");
    }, 4500);
  }

  function directUpload(files) {
    if (!files || files.length === 0 || !form) return;

    showUploadToast(files.length);
    renderPendingUploadTiles(files);

    const formData = new FormData();
    Array.from(files).forEach((file) => {
      formData.append("files[]", file);
    });

    const csrfToken =
      document.querySelector('meta[name="csrf-token"]')?.content ||
      (form ? form.querySelector('input[name="authenticity_token"]')?.value : "") ||
      "";
    if (csrfToken) {
      formData.append("authenticity_token", csrfToken);
    }

    const actionUrl = form.getAttribute("action") || "/uploads";

    fetch(actionUrl, {
      method: "POST",
      body: formData,
      headers: {
        "Accept": "application/json",
        "X-Requested-With": "XMLHttpRequest"
      }
    })
      .then((res) => {
        if (!res.ok) {
          return res.json().then((d) => {
            throw new Error(d.error || `Upload failed with HTTP ${res.status}`);
          });
        }
        return res.json();
      })
      .then((data) => {
        if (data && data.success) {
          finalizePendingUploadTiles(data.uploads);
          showSuccessToast(data.notice || "Upload successful!");
        } else {
          throw new Error(data.error || "Upload failed");
        }
      })
      .catch((err) => {
        removePendingUploadTiles();
        showErrorToast(err.message || "Failed to upload files. Please try again.");
      });
  }

  function bindPasteEvents() {
    window.addEventListener("paste", (e) => {
      if (!e.clipboardData || !e.clipboardData.files) return;
      const target = e.target;
      if (
        target &&
        (target.tagName === "INPUT" ||
          target.tagName === "TEXTAREA" ||
          target.isContentEditable)
      ) {
        return;
      }

      const files = e.clipboardData.files;
      if (files.length > 0) {
        e.preventDefault();
        directUpload(files);
      }
    });
  }

  function bindNativeFileInput() {
    if (!fileInput) return;
    fileInput.addEventListener("change", () => {
      if (fileInput.files && fileInput.files.length > 0) {
        directUpload(fileInput.files);
      }
    });
  }

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

    if (window.innerWidth <= 768 || !orphStage) {
      cards.forEach((c) => c.classList.remove("is-dropping"));
      directUpload(files);
      isDropping = false;
      return;
    }

    orphStage.classList.add("mouth-open");
    orphStage.classList.remove("gulping");
    if (bubble) bubble.textContent = "Feed me files!";

    playDesktopDropEffect(files, dropX, dropY, () => {
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

  function bindOrphCompanion() {
    const card = document.querySelector("[data-upload-card]");
    if (!card) return;

    let eyeRafId = null;
    window.addEventListener("dragover", (e) => {
      if (!card.classList.contains("drag-active") && !card.classList.contains("drag-target")) {
        return;
      }
      if (!eyeRafId) {
        eyeRafId = requestAnimationFrame(() => {
          eyeRafId = null;
          updateEyeTracking(e.clientX, e.clientY);
        });
      }
    });
  }

  function updateEyeTracking(mouseX, mouseY) {
    const card = document.querySelector("[data-upload-card]");
    if (!card) return;

    const charEl = card.querySelector("[data-orph-character]");
    const leftPupil = card.querySelector("[data-orph-pupil-left]");
    const rightPupil = card.querySelector("[data-orph-pupil-right]");
    if (!charEl || !leftPupil || !rightPupil) return;

    const charRect = charEl.getBoundingClientRect();
    if (charRect.width === 0 || charRect.height === 0) return;

    const eyeLeftCenter = {
      x: charRect.left + charRect.width * 0.4435,
      y: charRect.top + charRect.height * 0.3125
    };
    const eyeRightCenter = {
      x: charRect.left + charRect.width * 0.5367,
      y: charRect.top + charRect.height * 0.3125
    };

    const maxEyeRadius = Math.max(2.5, charRect.width * 0.022);

    function trackPupil(center, pupilEl) {
      const dx = mouseX - center.x;
      const dy = mouseY - center.y;
      const dist = Math.hypot(dx, dy);

      if (dist === 0) {
        pupilEl.style.transform = "translate(0px, 0px)";
        return;
      }

      const angle = Math.atan2(dy, dx);
      const moveDist = Math.min(dist * 0.08, maxEyeRadius);
      const pupilX = Math.cos(angle) * moveDist;
      const pupilY = Math.sin(angle) * moveDist;

      pupilEl.style.transform = `translate(${pupilX.toFixed(2)}px, ${pupilY.toFixed(2)}px)`;
    }

    trackPupil(eyeLeftCenter, leftPupil);
    trackPupil(eyeRightCenter, rightPupil);
  }

  function init() {
    const formElement = document.querySelector("[data-dropzone-form]");
    if (!formElement) return;

    form = formElement;
    fileInput = document.querySelector("[data-dropzone-input]");

    if (!eventsBound) {
      eventsBound = true;
      bindDragAndDropEvents();
      bindPasteEvents();
      bindNativeFileInput();
      bindOrphCompanion();
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }

  document.addEventListener("turbo:load", init);
})();
