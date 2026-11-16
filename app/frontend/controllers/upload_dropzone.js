// Upload dropzone and clipboard paste controller
(function () {
  let initialized = false;
  let eventsBound = false;
  let form = null;
  let fileInput = null;
  let dragCounter = 0;
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

  function directUpload(files) {
    if (!files || files.length === 0 || !form) return;

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

    form.submit();
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
