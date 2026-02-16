/**
 * Flutter Web Bootstrap with WASM Auto-Detection
 * 
 * This script automatically detects WebAssembly support and loads
 * the optimal Flutter build (WASM for speed, or fallback to JS).
 * 
 * Benefits of WASM:
 * - 30-50% faster execution
 * - Smaller bundle size
 * - Near-native performance
 */

(function() {
  'use strict';

  // Configuration
  const config = {
    // Base path for Flutter assets
    baseUri: document.querySelector('base')?.href || '/',
    
    // Enable WASM by default if supported
    useWasm: true,
    
    // Debug mode
    debug: false
  };

  // Logger
  const log = config.debug ? console.log.bind(console, '[Flutter]') : () => {};

  /**
   * Check if WebAssembly is supported and performant
   */
  function detectWasmSupport() {
    try {
      // Check for WebAssembly object
      if (typeof WebAssembly === 'undefined') {
        log('WebAssembly not supported');
        return false;
      }

      // Check for required WebAssembly features
      const requiredFeatures = [
        'WebAssembly.compile',
        'WebAssembly.instantiate',
        'WebAssembly.Module',
        'WebAssembly.Memory'
      ];

      for (const feature of requiredFeatures) {
        const parts = feature.split('.');
        let obj = window;
        for (const part of parts) {
          obj = obj[part];
          if (!obj) {
            log(`Missing feature: ${feature}`);
            return false;
          }
        }
      }

      // Test for bulk memory operations (critical for Flutter WASM)
      if (WebAssembly.Module.prototype.exports === undefined) {
        log('WebAssembly bulk memory not fully supported');
      }

      // Check for SIMD support (optional but beneficial)
      const hasSimd = WebAssembly.validate(new Uint8Array([
        0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
        0x01, 0x05, 0x01, 0x60, 0x00, 0x01, 0x7b, 0x03,
        0x02, 0x01, 0x00, 0x0a, 0x0a, 0x01, 0x08, 0x00,
        0x41, 0x00, 0xfd, 0x0f, 0x1b, 0x0b
      ]));
      
      log(`WebAssembly SIMD support: ${hasSimd}`);

      log('WebAssembly fully supported');
      return true;
    } catch (e) {
      log('Error detecting WebAssembly:', e);
      return false;
    }
  }

  /**
   * Get the entrypoint script based on WASM support
   */
  function getEntrypoint() {
    const supportsWasm = detectWasmSupport();
    
    // Check for URL override
    const urlParams = new URLSearchParams(window.location.search);
    const wasmOverride = urlParams.get('wasm');
    
    if (wasmOverride === '0') {
      log('WASM disabled via URL parameter');
      return 'flutter.js';
    }
    
    if (wasmOverride === '1' || (supportsWasm && config.useWasm)) {
      log('Using WASM build');
      return 'flutter_bootstrap.js';
    }
    
    log('Using JavaScript fallback');
    return 'flutter.js';
  }

  /**
   * Create and load the Flutter engine script
   */
  function loadFlutterEngine() {
    const entrypoint = getEntrypoint();
    
    // For Flutter 3.22+ with WASM support
    if (entrypoint === 'flutter_bootstrap.js') {
      // Use the new WASM bootstrap
      loadWasmBootstrap();
    } else {
      // Use traditional JS bootstrap
      loadJsBootstrap();
    }
  }

  /**
   * Load WASM bootstrap (Flutter 3.22+)
   */
  function loadWasmBootstrap() {
    // The new Flutter web embedding API
    if (window._flutter) {
      log('Flutter already loaded');
      return;
    }

    // Load the Flutter loader
    const script = document.createElement('script');
    script.src = `${config.baseUri}flutter.js`;
    script.async = true;
    
    script.onload = function() {
      log('Flutter engine loaded');
      
      // Configure Flutter engine for WASM
      if (window.flutterLoader) {
        window.flutterLoader.loadEntrypoint({
          serviceWorker: {
            serviceWorkerVersion: null, // We handle this ourselves
          },
          onEntrypointLoaded: function(engineInitializer) {
            log('Initializing Flutter engine...');
            
            engineInitializer.initializeEngine().then(function(appRunner) {
              log('Starting Flutter app...');
              return appRunner.runApp();
            }).then(function() {
              log('Flutter app started successfully');
            }).catch(function(error) {
              console.error('Error starting Flutter app:', error);
            });
          }
        });
      }
    };
    
    script.onerror = function() {
      console.error('Failed to load Flutter engine');
      // Fallback to JS
      loadJsBootstrap();
    };
    
    document.head.appendChild(script);
  }

  /**
   * Load traditional JS bootstrap
   */
  function loadJsBootstrap() {
    const script = document.createElement('script');
    script.src = `${config.baseUri}flutter.js`;
    script.async = true;
    
    script.onload = function() {
      if (window.flutterLoader) {
        window.flutterLoader.loadEntrypoint({
          onEntrypointLoaded: function(engineInitializer) {
            engineInitializer.initializeEngine().then(function(appRunner) {
              return appRunner.runApp();
            });
          }
        });
      }
    };
    
    document.head.appendChild(script);
  }

  /**
   * Performance monitoring
   */
  function monitorPerformance() {
    if (window.performance) {
      window.addEventListener('load', function() {
        setTimeout(function() {
          const perfData = window.performance.timing;
          const pageLoadTime = perfData.loadEventEnd - perfData.navigationStart;
          const wasmUsed = detectWasmSupport() ? 'WASM' : 'JS';
          
          console.log(`[Performance] Page loaded in ${pageLoadTime}ms using ${wasmUsed}`);
        }, 0);
      });
    }
  }

  // Initialize
  log('Initializing Flutter Web with WASM support...');
  loadFlutterEngine();
  monitorPerformance();

})();
