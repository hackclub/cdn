(function() {
  let dropzone;
  let counter = 0;
  let fileInput, form;
  let initialized = false;

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

    // Handle file input change (supports multiple files)
    fileInput.addEventListener("change", (e) => {
      if (e.target.files.length > 0) {
        form.requestSubmit();
      }
    });
  }

  // Prevent default drag behaviors
  document.addEventListener("dragover", (e) => {
    e.preventDefault();
  });

  // Show overlay when dragging enters window
  document.addEventListener("dragenter", (e) => {
    if (!fileInput) return;
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
    if (counter === 0) {
      hideDropzone();
    }
  });

  // Handle file drop
  document.addEventListener("drop", (e) => {
    if (!fileInput) return;
    e.preventDefault();
    counter = 0;
    hideDropzone();

    const files = e.dataTransfer.files;
    if (files.length > 0) {
      fileInput.files = files;
      form.requestSubmit();
    }
  });

  // Show full-screen dropzone overlay
  function showDropzone() {
    if (!dropzone) {
      dropzone = document.createElement("div");
      dropzone.classList.add("file-dropzone");

      const title = document.createElement("h1");
      title.innerText = "Drop your files here";
      dropzone.appendChild(title);

      document.body.appendChild(dropzone);
      document.body.style.overflow = "hidden";

      // Force reflow for transition
      void dropzone.offsetWidth;

      dropzone.classList.add("visible");
    }
  }

  // Hide full-screen dropzone overlay
  function hideDropzone() {
    if (dropzone) {
      dropzone.remove();
      dropzone = null;
      document.body.style.overflow = "auto";
      counter = 0;
    }
  }

  // Initialize on first load
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }

  // Re-initialize on Turbo navigations
  document.addEventListener("turbo:load", init);
})();
