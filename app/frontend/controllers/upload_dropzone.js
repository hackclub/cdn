(function () {
  const DESKTOP_TITLES = [
    "Feed me, mortal",
    "Drop 'em like it's hot",
    "Your files look delicious",
    "Sacrifice your assets to Orph",
    "Nom nom nom...",
    "Down the hatch",
    "Mmm, fresh uploads"
  ];
  const DESKTOP_SUBTITLE = "Drop anywhere to feed Orph • Up to 40 files at once";

  let dropzone = null;
  let orphStage = null;
  let leftPupil = null;
  let rightPupil = null;
  let titleEl = null;
  let subtitleEl = null;

  let counter = 0;
  let fileInput = null;
  let form = null;
  let initialized = false;
  let mouthTimer = null;
  let isDropping = false;
  let hideTimer = null;

  function getRandomTitle() {
    return DESKTOP_TITLES[Math.floor(Math.random() * DESKTOP_TITLES.length)];
  }

  function init() {
    const formElement = document.querySelector("[data-dropzone-form]");
    if (!formElement) {
      fileInput = null;
      form = null;
      initialized = false;
      return;
    }

    if (initialized && form === formElement) return;

    form = formElement;
    fileInput = form.querySelector("[data-dropzone-input]");

    if (!fileInput) return;

    initialized = true;

    // Handle manual file input change
    fileInput.addEventListener("change", (e) => {
      const files = e.target.files;
      if (files && files.length > 0) {
        form.requestSubmit();
      }
    });

    // prefetch svg assets on load
    prefetchSvgAssets();
  }

  // prefetch svg assets so orph and file icons appear immediately on drag
  const PREFETCH_SVGS = [
    "/orph-closed-mouth.svg",
    "/orph-open-mouth.svg",
    "/file-icon.svg"
  ];

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

  // Prevent default drag behaviors and update eye tracking
  document.addEventListener("dragover", (e) => {
    e.preventDefault();
    if (e.dataTransfer) {
      e.dataTransfer.dropEffect = "copy";
    }

    // Return early on small screens (no eye tracking, animations, or pupil calculations)
    if (window.innerWidth <= 768) return;

    if (dropzone && orphStage) {
      updateEyeTracking(e.clientX, e.clientY);
    }
  });

  // Calculate pupil positions smoothly inside Orph eye cutouts with strict elliptical clamp
  function updateEyeTracking(mouseX, mouseY) {
    if (!orphStage || !leftPupil || !rightPupil) return;

    const stageRect = orphStage.getBoundingClientRect();
    if (stageRect.width === 0 || stageRect.height === 0) return;

    // Calibrated eye base centers inside Orph stage
    const leftEyeBaseX = stageRect.left + stageRect.width * 0.534;
    const leftEyeBaseY = stageRect.top + stageRect.height * 0.128;
    const rightEyeBaseX = stageRect.left + stageRect.width * 0.688;
    const rightEyeBaseY = stageRect.top + stageRect.height * 0.087;

    // Strict elliptical boundary limits in pixels to guarantee pupils never escape eye cutouts
    const leftMaxX = stageRect.width * 0.011;
    const leftMaxY = stageRect.height * 0.0050;

    const rightMaxX = stageRect.width * 0.0095;
    const rightMaxY = stageRect.height * 0.0042;

    // Left eye vector and exact ellipse clamp
    const rawLx = (mouseX - leftEyeBaseX) * 0.035;
    const rawLy = (mouseY - leftEyeBaseY) * 0.035;
    const scaleL = Math.max(1, Math.hypot(rawLx / leftMaxX, rawLy / leftMaxY));
    const offLx = rawLx / scaleL;
    const offLy = rawLy / scaleL;

    // Right eye vector and exact ellipse clamp
    const rawRx = (mouseX - rightEyeBaseX) * 0.035;
    const rawRy = (mouseY - rightEyeBaseY) * 0.035;
    const scaleR = Math.max(1, Math.hypot(rawRx / rightMaxX, rawRy / rightMaxY));
    const offRx = rawRx / scaleR;
    const offRy = rawRy / scaleR;

    leftPupil.style.transform = `translate(-50%, -50%) translate3d(${offLx.toFixed(2)}px, ${offLy.toFixed(2)}px, 0)`;
    rightPupil.style.transform = `translate(-50%, -50%) translate3d(${offRx.toFixed(2)}px, ${offRy.toFixed(2)}px, 0)`;
  }

  // Show overlay when dragging enters window
  document.addEventListener("dragenter", (e) => {
    if (!fileInput) return;
    if (e.dataTransfer && e.dataTransfer.types) {
      const types = Array.from(e.dataTransfer.types);
      if (!types.includes("Files")) return;
    }
    e.preventDefault();
    if (counter === 0) {
      showDropzone();
    }
    counter++;
  });

  // Hide overlay when dragging leaves window
  document.addEventListener("dragleave", (e) => {
    if (!fileInput) return;
    e.preventDefault();
    counter--;
    if (counter <= 0) {
      counter = 0;
      hideDropzone();
    }
  });

  // Cancel on Escape key
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && dropzone) {
      e.preventDefault();
      counter = 0;
      hideDropzone();
    }
  });

  // Clipboard Paste file support
  document.addEventListener("paste", (e) => {
    if (!fileInput) return;
    const items = e.clipboardData ? e.clipboardData.items : null;
    if (!items || items.length === 0) return;

    const files = [];
    for (let i = 0; i < items.length; i++) {
      if (items[i].kind === "file") {
        const file = items[i].getAsFile();
        if (file) files.push(file);
      }
    }
    if (files.length === 0) return;

    e.preventDefault();
    if (window.innerWidth <= 768) {
      const dt = new DataTransfer();
      files.forEach((f) => dt.items.add(f));
      fileInput.files = dt.files;
      form.requestSubmit();
      return;
    }

    if (isDropping) return;
    showDropzone();
    if (orphStage) orphStage.classList.add("mouth-open");

    executeUploadWithAnimation(files, window.innerWidth / 2, window.innerHeight / 2);
  });

  // Handle file drop
  document.addEventListener("drop", (e) => {
    if (!fileInput) return;
    e.preventDefault();
    counter = 0;

    const files = e.dataTransfer ? e.dataTransfer.files : null;
    if (!files || files.length === 0) {
      hideDropzone();
      return;
    }

    // Small screens (<= 768px): instant submission without mascot animation
    if (window.innerWidth <= 768) {
      hideDropzone();
      fileInput.files = files;
      form.requestSubmit();
      return;
    }

    // Desktop (> 768px): Among Us eject drift effect with synchronized background upload
    if (isDropping) return;

    const dropX = e.clientX || window.innerWidth / 2;
    const dropY = e.clientY || window.innerHeight / 2;

    executeUploadWithAnimation(files, dropX, dropY);
  });

  // Execute upload in background and ensure animation finishes before page refresh
  async function executeUploadWithAnimation(files, dropX, dropY) {
    if (!form) return;
    isDropping = true;

    // 1. Prepare FormData for immediate background upload
    const formData = new FormData();
    const csrfToken =
      form.querySelector('input[name="authenticity_token"]')?.value ||
      document.querySelector('meta[name="csrf-token"]')?.getAttribute("content");
    if (csrfToken) {
      formData.append("authenticity_token", csrfToken);
    }
    for (let i = 0; i < files.length; i++) {
      formData.append("files[]", files[i]);
    }

    // start upload immediately in the background
    const uploadPromise = fetch(form.action || "/uploads", {
      method: "POST",
      body: formData,
      headers: {
        "X-CSRF-Token": csrfToken || "",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
      }
    });

    // run drift animation in parallel
    const animationPromise = new Promise((resolve) => {
      playDesktopDropEffect(files, dropX, dropY, resolve);
    });

    try {
      // wait until icons enter the mouth
      await animationPromise;

      if (orphStage) {
        orphStage.classList.remove("mouth-open");
        orphStage.classList.add("gulping");
      }
      if (titleEl) titleEl.textContent = "Gulp! Uploading...";
      if (subtitleEl) subtitleEl.textContent = "Nomming your files...";

      // wait for upload to complete
      const response = await uploadPromise;

      if (!response.ok && response.status !== 302) {
        throw new Error(`Upload returned status ${response.status}`);
      }

      const html = await response.text();

      // slide away
      if (orphStage) {
        orphStage.classList.add("sliding-out");
      }

      await new Promise((resolve) => setTimeout(resolve, 360));

      // update page with newly uploaded files and flash notice
      if (html && html.includes("<body")) {
        document.open();
        document.write(html);
        document.close();
      } else {
        window.location.reload();
      }
    } catch (err) {
      if (titleEl) titleEl.textContent = "Upload failed";
      if (subtitleEl) subtitleEl.textContent = err.message || "Please try again";
      setTimeout(() => {
        isDropping = false;
        hideDropzone();
      }, 1800);
    }
  }

  // among us style zero-g eject drift into orph mouth
  function playDesktopDropEffect(files, dropX, dropY, onComplete) {
    if (!orphStage) {
      onComplete();
      return;
    }

    const stageRect = orphStage.getBoundingClientRect();
    const mouthX = stageRect.left + stageRect.width * 0.631;
    const mouthY = stageRect.top + stageRect.height * 0.290;

    const fileList = Array.from(files);
    const displayCount = Math.min(Math.max(fileList.length, 1), 10);
    let finishedCount = 0;

    // scale icon relative to orph stage
    const iconWidth = Math.round(stageRect.width * 0.115);
    const iconHeight = Math.round(iconWidth * 1.2);

    for (let i = 0; i < displayCount; i++) {
      const fileIcon = document.createElement("div");
      fileIcon.className = "orph-sucked-file";
      fileIcon.style.width = `${iconWidth}px`;
      fileIcon.style.height = `${iconHeight}px`;
      fileIcon.innerHTML = `<img src="/file-icon.svg" alt="file" draggable="false">`;

      document.body.appendChild(fileIcon);

      const spreadAngle = (i / displayCount) * Math.PI * 2;
      const spreadRadius = displayCount > 1 ? (10 + (i % 3) * 8) : 0;
      const startX = dropX + Math.cos(spreadAngle) * spreadRadius;
      const startY = dropY + Math.sin(spreadAngle) * spreadRadius;

      const dx = mouthX - startX;
      const dy = mouthY - startY;

      // constant velocity drift with steady 360 tumble
      const frames = [];
      const steps = 30;
      // Gentle tumble: continuous 360deg spin at uniform angular velocity across entire drift
      const spinDirection = (i % 2 === 0 ? 1 : -1);
      const totalRotation = spinDirection * 360;

      for (let s = 0; s <= steps; s++) {
        const t = s / steps;
        // Constant velocity drift through space straight to mouth center
        const posX = startX + dx * t;
        const posY = startY + dy * t;

        // Steady end-over-end tumble at constant speed (Among Us eject style)
        const rotation = (totalRotation * t).toFixed(1);

        // Gradually scales down into the distance/void (from 1.0 down to 0 at mouth entry)
        const scale = Math.max(0, 1 - Math.pow(t, 1.3));

        // Fade out right as it enters the mouth aperture
        const opacity = t > 0.94 ? Math.max(0, (1 - t) / 0.06) : 1;

        frames.push({
          transform: `translate3d(${posX.toFixed(1)}px, ${posY.toFixed(1)}px, 0) translate(-50%, -50%) scale(${scale.toFixed(3)}) rotate(${rotation}deg)`,
          opacity: opacity
        });
      }

      // Calm Among Us drift speed (1050ms)
      const duration = 1050;
      const delay = i * 75;

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

  // Show full-screen dropzone overlay
  function showDropzone() {
    if (hideTimer) {
      clearTimeout(hideTimer);
      hideTimer = null;
    }

    const isDesktop = window.innerWidth > 768;

    if (dropzone) {
      dropzone.classList.remove("exiting");
      dropzone.classList.add("visible");

      if (orphStage) {
        orphStage.classList.remove("sliding-out", "gulping");
      }

      if (titleEl) {
        titleEl.textContent = isDesktop ? getRandomTitle() : "Drop your files here";
      }
      if (subtitleEl) {
        subtitleEl.textContent = isDesktop ? DESKTOP_SUBTITLE : "Up to 40 files at once";
      }

      // Re-arm mouth opening timer on repeated entry
      if (isDesktop && orphStage) {
        if (mouthTimer) clearTimeout(mouthTimer);
        if (!orphStage.classList.contains("mouth-open")) {
          mouthTimer = setTimeout(() => {
            if (orphStage && dropzone && !isDropping) {
              orphStage.classList.add("mouth-open");
            }
          }, 200);
        }
      }
      return;
    }

    dropzone = document.createElement("div");
    dropzone.className = "file-dropzone";

    const container = document.createElement("div");
    container.className = "dropzone-container";

    // Left side: Orph Stage
    orphStage = document.createElement("div");
    orphStage.className = "orph-stage";

    const character = document.createElement("div");
    character.className = "orph-character";

    const imgClosed = document.createElement("img");
    imgClosed.src = "/orph-closed-mouth.svg";
    imgClosed.className = "orph-graphic orph-closed";
    imgClosed.alt = "Orph closed mouth";

    const imgOpen = document.createElement("img");
    imgOpen.src = "/orph-open-mouth.svg";
    imgOpen.className = "orph-graphic orph-open";
    imgOpen.alt = "Orph open mouth";

    leftPupil = document.createElement("div");
    leftPupil.className = "orph-pupil orph-pupil-left";

    rightPupil = document.createElement("div");
    rightPupil.className = "orph-pupil orph-pupil-right";

    character.appendChild(imgClosed);
    character.appendChild(imgOpen);
    character.appendChild(leftPupil);
    character.appendChild(rightPupil);

    const speechBubble = document.createElement("div");
    speechBubble.className = "orph-speech-bubble";
    speechBubble.textContent = "Gulp! Uploading...";

    orphStage.appendChild(character);
    orphStage.appendChild(speechBubble);
    container.appendChild(orphStage);

    // Right side: Content
    const content = document.createElement("div");
    content.className = "dropzone-content";

    // Modern upload SVG icon for mobile fallback
    const uploadIcon = document.createElement("div");
    uploadIcon.className = "dropzone-upload-icon";
    uploadIcon.innerHTML = `<svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="17 8 12 3 7 8"></polyline><line x1="12" y1="3" x2="12" y2="15"></line></svg>`;

    titleEl = document.createElement("h1");
    titleEl.className = "dropzone-title";
    titleEl.textContent = isDesktop ? getRandomTitle() : "Drop your files here";

    subtitleEl = document.createElement("p");
    subtitleEl.className = "dropzone-subtitle";
    subtitleEl.textContent = isDesktop ? DESKTOP_SUBTITLE : "Up to 40 files at once";

    content.appendChild(uploadIcon);
    content.appendChild(titleEl);
    content.appendChild(subtitleEl);
    container.appendChild(content);

    dropzone.appendChild(container);
    document.body.appendChild(dropzone);
    document.body.style.overflow = "hidden";

    // Trigger reflow to start slide-in transition
    void dropzone.offsetWidth;
    dropzone.classList.add("visible");

    // Mouth state: starts with closed mouth, snaps to open mouth after ~200ms
    if (isDesktop) {
      if (mouthTimer) clearTimeout(mouthTimer);
      mouthTimer = setTimeout(() => {
        if (orphStage && dropzone && !isDropping) {
          orphStage.classList.add("mouth-open");
        }
      }, 200);
    }
  }

  // Hide full-screen dropzone overlay cleanly
  function hideDropzone() {
    if (!dropzone || isDropping) return;

    if (mouthTimer) {
      clearTimeout(mouthTimer);
      mouthTimer = null;
    }

    // Cleanly snap mouth shut and slide Orph out
    if (orphStage) {
      orphStage.classList.remove("mouth-open");
    }

    dropzone.classList.remove("visible");
    dropzone.classList.add("exiting");

    hideTimer = setTimeout(() => {
      if (dropzone) {
        dropzone.remove();
        dropzone = null;
        orphStage = null;
        leftPupil = null;
        rightPupil = null;
        titleEl = null;
        subtitleEl = null;
        document.body.style.overflow = "auto";
        counter = 0;
        hideTimer = null;
      }
    }, 320);
  }

  // Initialize on first load and prefetch assets immediately
  prefetchSvgAssets();

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }

  // Re-initialize on Turbo navigations
  document.addEventListener("turbo:load", () => {
    init();
    prefetchSvgAssets();
  });
})();
