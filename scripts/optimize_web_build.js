#!/usr/bin/env node

/**
 * Flutter Web Build Optimizer
 * 
 * This script optimizes Flutter web builds by:
 * 1. Adding hash to all resource files (except index.html) for cache busting
 * 2. Splitting main.dart.js into multiple chunks for parallel loading
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

// Configuration
const BUILD_DIR = path.join(__dirname, '..', 'build', 'web');
const CHUNK_SIZE = 500 * 1024; // 500KB per chunk
const INDEX_HTML = 'index.html';

// Resource map: original path -> hashed path
const resourceMap = new Map();

// Dependency version cache: file path -> version signature
// Used to skip processing unchanged dependency files
const DEPENDENCY_VERSION_CACHE_FILE = path.join(__dirname, '..', '.dependency_versions.json');
let dependencyVersionCache = {};

/**
 * Calculate MD5 hash of a file
 */
function calculateHash(filePath) {
  const content = fs.readFileSync(filePath);
  return crypto.createHash('md5').update(content).digest('hex').substring(0, 8);
}

/**
 * Get file extension
 */
function getExtension(filePath) {
  return path.extname(filePath);
}

/**
 * Get file name without extension
 */
function getBaseName(filePath) {
  const ext = getExtension(filePath);
  return path.basename(filePath, ext);
}

/**
 * Generate hashed filename
 */
function generateHashedName(filePath) {
  const hash = calculateHash(filePath);
  const ext = getExtension(filePath);
  // Use base name without existing hashes to prevent double hashing
  const baseNameWithoutHash = getBaseNameWithoutHash(filePath);
  // Remove extension from baseNameWithoutHash if it still has it
  let baseName = baseNameWithoutHash;
  if (baseNameWithoutHash.endsWith(ext)) {
    baseName = baseNameWithoutHash.substring(0, baseNameWithoutHash.length - ext.length);
  }
  const dir = path.dirname(filePath);
  const newName = `${baseName}-${hash}${ext}`;
  return path.join(dir, newName);
}

/**
 * Recursively find all files in directory
 */
function findAllFiles(dir, fileList = []) {
  const files = fs.readdirSync(dir);
  
  files.forEach(file => {
    const filePath = path.join(dir, file);
    const stat = fs.statSync(filePath);
    
    if (stat.isDirectory()) {
      findAllFiles(filePath, fileList);
    } else {
      // Skip index.html
      if (path.basename(filePath) !== INDEX_HTML) {
        fileList.push(filePath);
      }
    }
  });
  
  return fileList;
}

/**
 * Get relative path from build directory
 */
function getRelativePath(filePath) {
  return path.relative(BUILD_DIR, filePath).replace(/\\/g, '/');
}

/**
 * Extract base filename without hash suffixes
 * e.g., "AssetManifest.bin-c14fcfb0-c14fcfb0.json" -> "AssetManifest.bin.json"
 * e.g., "canvaskit-48af530c-117b9fe7-122c1611.wasm" -> "canvaskit.wasm"
 */
function getBaseNameWithoutHash(filePath) {
  const baseName = path.basename(filePath);
  // Remove all hash suffixes: -hash1-hash2-hash3.ext -> .ext
  // Pattern matches: - followed by 8 hex digits, repeated any number of times
  // Use a more aggressive pattern that removes ALL consecutive hash patterns
  const withoutHash = baseName.replace(/(-[a-f0-9]{8})+(?=\.)/gi, '');
  return withoutHash;
}

/**
 * Check if filename already has a hash suffix
 */
function hasHashSuffix(filePath) {
  const baseName = path.basename(filePath);
  const baseNameWithoutHash = getBaseNameWithoutHash(filePath);
  // If base name changed after removing hashes, it means file has hash suffixes
  return baseName !== baseNameWithoutHash;
}

/**
 * Rename file with hash
 */
function hashFile(filePath) {
  // Check if file exists before processing
  if (!fs.existsSync(filePath)) {
    const relativePath = getRelativePath(filePath);
    console.warn(`⚠️  Warning: File does not exist, skipping: ${relativePath}`);
    return filePath; // Return original path even though file doesn't exist
  }
  
  const originalBaseName = path.basename(filePath);
  const dir = path.dirname(filePath);
  const ext = getExtension(filePath);
  
  // Always remove existing hashes first to prevent accumulation
  let cleanFilePath = filePath;
  if (hasHashSuffix(filePath)) {
    const baseNameWithoutHash = getBaseNameWithoutHash(filePath);
    // Ensure extension is preserved
    let cleanBaseName = baseNameWithoutHash;
    if (!cleanBaseName.endsWith(ext)) {
      cleanBaseName = cleanBaseName + ext;
    }
    const cleanPath = path.join(dir, cleanBaseName);
    
    // Only rename if different and clean path doesn't exist or is different file
    if (filePath !== cleanPath) {
      try {
        // Check if clean path exists before accessing
        if (fs.existsSync(cleanPath)) {
          // If clean file exists, check if it's the same file
          const cleanStats = fs.statSync(cleanPath);
          const currentStats = fs.statSync(filePath);
          // If same size and modification time, they're likely the same, delete hashed version
          if (cleanStats.size === currentStats.size && 
              Math.abs(cleanStats.mtimeMs - currentStats.mtimeMs) < 1000) {
            fs.unlinkSync(filePath);
            cleanFilePath = cleanPath;
          } else {
            // Different files, keep hashed version but use clean name for new hash
            // But we need to use the existing file, so use cleanPath
            cleanFilePath = cleanPath;
          }
        } else {
          // Clean path doesn't exist, rename to remove hashes
          fs.renameSync(filePath, cleanPath);
          cleanFilePath = cleanPath;
        }
      } catch (error) {
        // If rename fails, continue with original path
        console.warn(`⚠️  Warning: Could not remove existing hashes from ${originalBaseName}: ${error.message}`);
        // Ensure file still exists, if not return original path
        if (!fs.existsSync(filePath)) {
          return filePath;
        }
      }
    }
  }
  
  // Verify clean file path exists before generating hash
  if (!fs.existsSync(cleanFilePath)) {
    const relativePath = getRelativePath(cleanFilePath);
    console.warn(`⚠️  Warning: Clean file path does not exist, skipping: ${relativePath}`);
    // Try to use original path if it exists
    if (fs.existsSync(filePath)) {
      cleanFilePath = filePath;
    } else {
      return filePath; // Return original path even though file doesn't exist
    }
  }
  
  // Now generate new hash based on clean file path
  const hashedPath = generateHashedName(cleanFilePath);
  const relativePath = getRelativePath(cleanFilePath);
  const relativeHashedPath = getRelativePath(hashedPath);
  
  // Check if the hashed filename would be too long (max 255 chars on most filesystems)
  const hashedBaseName = path.basename(hashedPath);
  if (hashedBaseName.length > 200) {
    console.warn(`⚠️  Warning: Filename too long, skipping hashing: ${relativePath} (${hashedBaseName.length} chars)`);
    // Use original path without hashing
    if (!resourceMap.has(relativePath)) {
      resourceMap.set(relativePath, relativePath);
    }
    return cleanFilePath;
  }
  
  // Only rename if different and file exists
  if (cleanFilePath !== hashedPath && fs.existsSync(cleanFilePath)) {
    try {
      fs.renameSync(cleanFilePath, hashedPath);
      resourceMap.set(relativePath, relativeHashedPath);
      console.log(`Hashed: ${relativePath} -> ${relativeHashedPath}`);
    } catch (error) {
      if (error.code === 'ENAMETOOLONG') {
        console.warn(`⚠️  Warning: Filename too long, skipping hashing: ${relativePath}`);
        // Use original path without hashing
        if (!resourceMap.has(relativePath)) {
          resourceMap.set(relativePath, relativePath);
        }
        return cleanFilePath;
      }
      if (error.code === 'ENOENT') {
        console.warn(`⚠️  Warning: File not found during rename: ${relativePath}`);
        return cleanFilePath;
      }
      throw error;
    }
  }
  
  return hashedPath;
}

/**
 * Update references in text content
 * @param {string} content - File content to update
 * @param {string} filePath - Path to the file being processed
 * @param {Map} resourceMapToUse - Resource map to use (can be filtered for performance)
 */
function updateReferences(content, filePath, resourceMapToUse = resourceMap) {
  let updated = content;
  
  // Performance optimization: Only process if content actually contains references
  // Build a quick check set of basenames to avoid unnecessary processing
  const contentLower = content.toLowerCase();
  const relevantMappings = [];
  
  // For very large files, use a more efficient approach: batch processing
  const isLargeFile = content.length > 2 * 1024 * 1024; // 2MB threshold
  const maxMappingsToCheck = isLargeFile ? 1000 : 3000; // Reduced for better performance
  
  // Use the provided resource map (may be filtered)
  resourceMapToUse.forEach((hashedPath, originalPath) => {
    const originalBase = path.basename(originalPath);
    // Quick check: only process if filename appears in content
    // For large files, use indexOf which is faster than includes for single checks
    if (isLargeFile) {
      if (contentLower.indexOf(originalBase.toLowerCase()) === -1 && 
          contentLower.indexOf(originalPath.toLowerCase()) === -1) {
        return; // Skip this mapping - not referenced in this file
      }
    } else {
      if (!contentLower.includes(originalBase.toLowerCase()) && 
          !contentLower.includes(originalPath.toLowerCase())) {
        return; // Skip this mapping - not referenced in this file
      }
    }
    relevantMappings.push({ hashedPath, originalPath });
    
    // Limit mappings for very large resource maps to avoid memory issues
    if (relevantMappings.length >= maxMappingsToCheck) {
      return; // Stop collecting more mappings
    }
  });
  
  // Sort by path length (longest first) to handle nested paths correctly
  relevantMappings.sort((a, b) => b.originalPath.length - a.originalPath.length);
  
  // For large files, process in batches to avoid blocking
  if (isLargeFile && relevantMappings.length > 100) {
    // Process in smaller batches for large files
    const batchSize = 50;
    for (let i = 0; i < relevantMappings.length; i += batchSize) {
      const batch = relevantMappings.slice(i, i + batchSize);
      batch.forEach(({ hashedPath, originalPath }) => {
        updated = processMapping(updated, hashedPath, originalPath);
      });
    }
  } else {
    // Process all mappings for normal files
    relevantMappings.forEach(({ hashedPath, originalPath }) => {
      updated = processMapping(updated, hashedPath, originalPath);
    });
  }
  
  return updated;
}

/**
 * Process a single mapping (extracted for batch processing)
 */
function processMapping(content, hashedPath, originalPath) {
  let updated = content;
    const originalBase = path.basename(originalPath);
    const hashedBase = path.basename(hashedPath);
    const originalDir = path.dirname(originalPath);
    const hashedDir = path.dirname(hashedPath);
    
    // 1. Exact path matches (with quotes)
    updated = updated.replace(new RegExp(`"${escapeRegex(originalPath)}"`, 'g'), `"${hashedPath}"`);
    updated = updated.replace(new RegExp(`'${escapeRegex(originalPath)}'`, 'g'), `'${hashedPath}'`);
    updated = updated.replace(new RegExp(`\`${escapeRegex(originalPath)}\``, 'g'), `\`${hashedPath}\``);
    
    // 2. Filename matches in paths
    // Match: "path/to/filename.ext" or 'path/to/filename.ext'
    const filenamePattern = escapeRegex(originalBase);
    // Use string concatenation to avoid template literal issues with backticks
    const quotePattern = '(["\'`])';
    const pathPattern = '([^"\'`]*?)';
    updated = updated.replace(
      new RegExp(quotePattern + pathPattern + filenamePattern + quotePattern, 'g'),
      (match, quote1, prefix, quote2) => {
        // Preserve the directory structure if it matches
        if (prefix.endsWith(originalDir)) {
          return quote1 + prefix.replace(originalDir, hashedDir) + hashedBase + quote2;
        }
        return quote1 + prefix + hashedBase + quote2;
      }
    );
    
    // 3. URL references: url('path/to/file.ext')
    updated = updated.replace(
      new RegExp(`url\\(['"]?([^'"]*?)${filenamePattern}['"]?\\)`, 'gi'),
      (match, prefix) => {
        if (prefix.endsWith(originalDir)) {
          return `url('${prefix.replace(originalDir, hashedDir)}${hashedBase}')`;
        }
        return `url('${prefix}${hashedBase}')`;
      }
    );
    
    // 4. HTML attributes: src="file.ext", href="file.ext"
    updated = updated.replace(
      new RegExp(`(src|href|data-src|data-href)=["']([^"']*?)${filenamePattern}["']`, 'gi'),
      (match, attr, prefix) => {
        if (prefix.endsWith(originalDir)) {
          return `${attr}="${prefix.replace(originalDir, hashedDir)}${hashedBase}"`;
        }
        return `${attr}="${prefix}${hashedBase}"`;
      }
    );
    
    // 5. JSON property values: {"src": "file.ext"}
    updated = updated.replace(
      new RegExp(`(["'](?:src|href|url|path|file|mainJsPath)["']\\s*:\\s*["'])([^"']*?)${filenamePattern}(["'])`, 'gi'),
      (match, prefix, pathPrefix, suffix) => {
        if (pathPrefix.endsWith(originalDir)) {
          return prefix + pathPrefix.replace(originalDir, hashedDir) + hashedBase + suffix;
        }
        return prefix + pathPrefix + hashedBase + suffix;
      }
    );
    
    // 6. Dynamic import() statements: import("path/to/file.js")
    updated = updated.replace(
      new RegExp(`import\\(['"]([^'"]*?)${filenamePattern}['"]\\)`, 'g'),
      (match, prefix) => {
        if (prefix.endsWith(originalDir)) {
          return `import('${prefix.replace(originalDir, hashedDir)}${hashedBase}')`;
        }
        return `import('${prefix}${hashedBase}')`;
      }
    );
    
    // 7. Service Worker file references (in JSON format)
    // Pattern: "canvaskit/chromium/canvaskit-86e461cf.js": "hash"
    // Match both with and without quotes around the path
    // Note: Service Worker uses MD5 hash of file content (32 chars)
    try {
      const hashedFilePath = path.join(BUILD_DIR, hashedPath);
      let fileHash = '';
      if (fs.existsSync(hashedFilePath)) {
        const fileContent = fs.readFileSync(hashedFilePath);
        fileHash = crypto.createHash('md5').update(fileContent).digest('hex');
      } else {
        // Fallback: use hash from filename if file doesn't exist
        const hashMatch = hashedBase.match(/-([a-f0-9]{8})/i);
        fileHash = hashMatch ? hashMatch[1].repeat(4) : '00000000000000000000000000000000';
      }
      
      updated = updated.replace(
        new RegExp(`(["'])([^"']*?)${escapeRegex(originalBase)}\\1\\s*:\\s*["'][^"']*["']`, 'g'),
        (match, quote, prefix) => {
          if (prefix.endsWith(originalDir) || prefix === originalDir) {
            const newPrefix = prefix.endsWith(originalDir) 
              ? prefix.replace(originalDir, hashedDir)
              : hashedDir;
            return `${quote}${newPrefix}${hashedBase}${quote}: "${fileHash}"`;
          }
          return `${quote}${prefix}${hashedBase}${quote}: "${fileHash}"`;
        }
      );
      
      // 7b. Service Worker file references without quotes around path
      // Pattern: canvaskit/chromium/canvaskit-86e461cf.js: "hash"
      updated = updated.replace(
        new RegExp(`([^"']*?)${escapeRegex(originalBase)}\\s*:\\s*["'][^"']*["']`, 'g'),
        (match, prefix) => {
          if (prefix.endsWith(originalDir) || prefix === originalDir) {
            const newPrefix = prefix.endsWith(originalDir) 
              ? prefix.replace(originalDir, hashedDir)
              : hashedDir;
            return `${newPrefix}${hashedBase}: "${fileHash}"`;
          }
          return `${prefix}${hashedBase}: "${fileHash}"`;
        }
      );
    } catch (e) {
      // If hash calculation fails, skip this update
      console.warn(`Warning: Failed to calculate hash for ${hashedPath}: ${e.message}`);
    }
    
    // 8. CanvasKit path fixes: canvaskit/chromium/xxx -> canvaskit/xxx
    // Fix paths that reference chromium subdirectory but files are in canvaskit root
    if (originalPath.includes('canvaskit/') && !originalPath.includes('chromium/')) {
      // If the hashed path doesn't have chromium/, but code references it with chromium/
      updated = updated.replace(
        new RegExp(`canvaskit/chromium/${escapeRegex(hashedBase)}`, 'g'),
        hashedPath.replace(/^canvaskit\//, 'canvaskit/')
      );
    }
    
    // 9. Fix Service Worker manifest references: avoid replacing variable method calls
    // Pattern: await manifest.json() where manifest is a variable, not a filename
    // We should NOT replace variable.method() calls, only string literals
    const jsonFilePattern = escapeRegex(originalBase);
    if (jsonFilePattern.endsWith('.json')) {
      // Avoid replacing JSON filenames that are part of variable method calls
      // Pattern: variable.json() should not be replaced
      // Only replace if it's a string literal (in quotes)
      updated = updated.replace(
        new RegExp(`([^a-zA-Z0-9_])${jsonFilePattern}([^()])`, 'g'),
        (match, before, after) => {
          // Don't replace if followed by () (function/method call)
          if (after === '(') {
            return match; // Keep original - this is a method call, not a filename
          }
          return before + hashedBase + after;
        }
      );
    }
    
  // 10. Simple string replacement for exact matches (fallback)
  // But skip if it's a JSON file that might be in a method call
  if (!originalBase.endsWith('.json')) {
    updated = updated.replace(new RegExp(escapeRegex(originalPath), 'g'), hashedPath);
  }
  
  return updated;
}

/**
 * Escape special regex characters
 */
function escapeRegex(str) {
  return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/**
 * Check if file content already contains hashed paths (skip if already processed)
 * @param {string} content - File content to check
 * @param {Map} resourceMapToUse - Resource map to check against
 * @returns {boolean} - True if file appears to already be processed
 */
function isFileAlreadyProcessed(content, resourceMapToUse) {
  // Sample a few mappings to check if file is already processed
  // If we find hashed paths in the content, likely already processed
  let sampleCount = 0;
  const maxSamples = Math.min(10, resourceMapToUse.size); // Check up to 10 samples
  
  for (const [originalPath, hashedPath] of resourceMapToUse) {
    if (sampleCount >= maxSamples) break;
    
    const originalBase = path.basename(originalPath);
    const hashedBase = path.basename(hashedPath);
    
    // If file contains hashed path but not original path, it's likely already processed
    // But we need to be careful - check if hashed path is actually in the file
    if (hashedPath !== originalPath && content.includes(hashedBase)) {
      // Check if original path is NOT in content (meaning it was already replaced)
      if (!content.includes(originalBase) || content.indexOf(hashedBase) < content.indexOf(originalBase)) {
        sampleCount++;
        continue;
      }
    }
    
    // If original path is still in content and hashed path is not, needs processing
    if (content.includes(originalBase) && !content.includes(hashedBase)) {
      return false; // Definitely needs processing
    }
    
    sampleCount++;
  }
  
  // If we sampled and all samples suggest it's processed, likely already done
  // But be conservative - only skip if we're confident
  if (sampleCount >= 5) {
    // Additional check: count how many original paths vs hashed paths are in content
    let originalCount = 0;
    let hashedCount = 0;
    let checkCount = 0;
    
    for (const [originalPath, hashedPath] of resourceMapToUse) {
      if (checkCount >= 20) break; // Check up to 20 more mappings
      
      const originalBase = path.basename(originalPath);
      const hashedBase = path.basename(hashedPath);
      
      if (content.includes(originalBase)) originalCount++;
      if (content.includes(hashedBase)) hashedCount++;
      
      checkCount++;
    }
    
    // If we see more hashed paths than original paths, likely already processed
    if (hashedCount > originalCount * 2) {
      return true;
    }
  }
  
  return false; // Default: process the file to be safe
}

/**
 * Update file references
 * @param {string} filePath - Path to file to update
 * @param {Map} resourceMapToUse - Resource map to use (can be filtered for performance)
 * @returns {boolean} - True if file was updated, false if skipped or unchanged
 */
function updateFileReferences(filePath, resourceMapToUse = resourceMap) {
  try {
  const content = fs.readFileSync(filePath, 'utf8');
    
    // Quick check: if file appears already processed, skip it
    if (isFileAlreadyProcessed(content, resourceMapToUse)) {
      return false; // File already processed, skip
    }
    
    const updated = updateReferences(content, filePath, resourceMapToUse);
  
  if (content !== updated) {
    fs.writeFileSync(filePath, updated, 'utf8');
      return true; // File was updated
    }
    
    return false; // File unchanged
  } catch (error) {
    console.warn(`⚠️  Failed to process file: ${getRelativePath(filePath)} - ${error.message}`);
    // Continue processing other files even if one fails
    return false;
  }
}

/**
 * Split main.dart.js into chunks
 */
function splitMainDartJs(mainDartJsPath) {
  console.log('\n=== Splitting main.dart.js ===');
  
  const content = fs.readFileSync(mainDartJsPath, 'utf8');
  const fileSize = content.length;
  const chunks = [];
  const chunkCount = Math.ceil(fileSize / CHUNK_SIZE);
  
  console.log(`File size: ${(fileSize / 1024 / 1024).toFixed(2)}MB`);
  console.log(`Splitting into ${chunkCount} chunks (${(CHUNK_SIZE / 1024).toFixed(0)}KB per chunk)`);
  
  // Split into chunks
  for (let i = 0; i < chunkCount; i++) {
    const start = i * CHUNK_SIZE;
    const end = Math.min(start + CHUNK_SIZE, fileSize);
    const chunk = content.substring(start, end);
    chunks.push(chunk);
  }
  
  // Get original file info
  const hash = calculateHash(mainDartJsPath);
  const baseName = getBaseName(mainDartJsPath);
  const ext = getExtension(mainDartJsPath);
  const dir = path.dirname(mainDartJsPath);
  
  // Write chunk files
  const chunkFiles = [];
  chunks.forEach((chunk, index) => {
    const chunkFileName = `${baseName}-chunk${index}${ext}`;
    const chunkPath = path.join(dir, chunkFileName);
    fs.writeFileSync(chunkPath, chunk, 'utf8');
    chunkFiles.push(chunkFileName);
    console.log(`Created chunk ${index + 1}/${chunkCount}: ${chunkFileName} (${(chunk.length / 1024).toFixed(2)}KB)`);
  });
  
  // Delete original file
  fs.unlinkSync(mainDartJsPath);
  console.log(`Deleted original: ${path.basename(mainDartJsPath)}`);
  
  return {
    chunkFiles,
    chunkCount,
    hash,
    baseName
  };
}

/**
 * Create chunk loader script
 */
function createChunkLoader(chunkInfo) {
  const baseName = chunkInfo.baseName;
  const loaderScript = `
// Chunk loader for ${baseName}.js
// Loads chunks in parallel and concatenates them before execution
(function() {
  'use strict';
  
  const chunks = ${JSON.stringify(chunkInfo.chunkFiles)};
  const basePath = document.baseURI || '';
  let loadedChunks = 0;
  const totalChunks = chunks.length;
  
  console.log(\`Loading \${totalChunks} chunks for ${baseName}.js...\`);
  
  // Load all chunks in parallel using XHR
  const loadPromises = chunks.map((chunk, index) => {
    return new Promise((resolve, reject) => {
      const xhr = new XMLHttpRequest();
      xhr.open('GET', basePath + chunk, true);
      xhr.onload = function() {
        if (xhr.status === 200 || xhr.status === 0) {
          loadedChunks++;
          console.log(\`Loaded chunk \${index + 1}/\${totalChunks} (\${((loadedChunks / totalChunks) * 100).toFixed(1)}%)\`);
          resolve(xhr.responseText);
        } else {
          reject(new Error(\`Failed to load chunk \${index + 1}: HTTP \${xhr.status}\`));
        }
      };
      xhr.onerror = function() {
        reject(new Error(\`Network error loading chunk \${index + 1}\`));
      };
      xhr.send();
    });
  });
  
  // Wait for all chunks to load, then concatenate and execute
  Promise.all(loadPromises)
    .then(chunkContents => {
      console.log('All chunks loaded, concatenating...');
      const fullCode = chunkContents.join('');
      
      // Create and execute script
      const script = document.createElement('script');
      script.type = 'application/javascript';
      script.textContent = fullCode;
      
      // Insert before other scripts to maintain execution order
      const firstScript = document.getElementsByTagName('script')[0];
      if (firstScript && firstScript.parentNode) {
        firstScript.parentNode.insertBefore(script, firstScript);
      } else {
        document.head.appendChild(script);
      }
      
      console.log('${baseName}.js chunks loaded and executed successfully');
    })
    .catch(error => {
      console.error('Error loading ${baseName}.js chunks:', error);
      // Try to show user-friendly error
      if (document.body) {
        document.body.innerHTML = '<div style="padding: 20px; text-align: center; font-family: sans-serif;"><h2>Loading Error</h2><p>Failed to load application resources. Please refresh the page and try again.</p></div>';
      }
      throw error;
    });
})();
`;
  
  const loaderPath = path.join(BUILD_DIR, `chunk-loader-${baseName}.js`);
  fs.writeFileSync(loaderPath, loaderScript.trim(), 'utf8');
  console.log(`Created chunk loader: chunk-loader-${baseName}.js`);
  
  return `chunk-loader-${baseName}.js`;
}

/**
 * Update index.html to use chunk loader
 */
function updateIndexHtml(chunkLoaderPath) {
  const indexPath = path.join(BUILD_DIR, INDEX_HTML);
  let content = fs.readFileSync(indexPath, 'utf8');
  
  // Replace flutter_bootstrap.js with chunk loader
  content = content.replace(
    /<script[^>]*src=["']flutter_bootstrap\.js["'][^>]*><\/script>/i,
    `<script src="${chunkLoaderPath}" async></script>`
  );
  
  fs.writeFileSync(indexPath, content, 'utf8');
  console.log(`Updated ${INDEX_HTML} to use chunk loader`);
}

/**
 * Create copies of canvaskit files with original filenames (without hash)
 * This ensures Flutter can find canvaskit files by their original names
 */
function createCanvaskitOriginals() {
  const canvaskitDir = path.join(BUILD_DIR, 'canvaskit');
  if (!fs.existsSync(canvaskitDir)) {
    return;
  }
  
  console.log('Creating canvaskit file copies for original filenames...');
  
  // Process both root canvaskit directory and chromium subdirectory
  const canvaskitDirs = [
    canvaskitDir,
    path.join(canvaskitDir, 'chromium')
  ];
  
  canvaskitDirs.forEach(canvaskitSubDir => {
    if (!fs.existsSync(canvaskitSubDir)) {
      return;
    }
    
    // Find all canvaskit files
    const canvaskitFiles = fs.readdirSync(canvaskitSubDir)
      .filter(f => {
        const fullPath = path.join(canvaskitSubDir, f);
        try {
          const stat = fs.statSync(fullPath);
          return stat.isFile() && /\.(js|wasm|symbols)$/i.test(f);
        } catch (e) {
          return false;
        }
      })
      .map(f => path.join(canvaskitSubDir, f));
    
    if (canvaskitFiles.length === 0) {
      return;
    }
    
    // Group files by base name (without hash)
    const filesByBaseName = new Map();
    
    canvaskitFiles.forEach(filePath => {
      const fileName = path.basename(filePath);
      const extMatch = fileName.match(/\.([^.]+)$/);
      if (!extMatch) {
        return;
      }
      const extension = extMatch[0];
      const nameWithoutExt = fileName.substring(0, fileName.length - extension.length);
      const nameWithoutHash = nameWithoutExt.replace(/(-[a-f0-9]{8})+$/i, '');
      const baseName = nameWithoutHash + extension;
      
      if (!filesByBaseName.has(baseName)) {
        filesByBaseName.set(baseName, []);
      }
      filesByBaseName.get(baseName).push({ path: filePath, fileName });
    });
    
    // Create original filename copies
    filesByBaseName.forEach((files, baseName) => {
      // Find the file with the most hashes (likely the most recent/complete one)
      const sortedFiles = files.sort((a, b) => {
        const aHashCount = (a.fileName.match(/-[a-f0-9]{8}/gi) || []).length;
        const bHashCount = (b.fileName.match(/-[a-f0-9]{8}/gi) || []).length;
        return bHashCount - aHashCount;
      });
      const sourceFile = sortedFiles[0];
      
      // Create original filename copy (no hash)
      if (baseName !== sourceFile.fileName) {
        const originalPath = path.join(canvaskitSubDir, baseName);
        if (fs.existsSync(originalPath)) {
          try {
            const stat = fs.statSync(originalPath);
            if (!stat.isFile() || stat.isSymbolicLink()) {
              fs.unlinkSync(originalPath);
            } else {
              return; // Already exists
            }
          } catch (e) {
            // Ignore errors
          }
        }
        
        try {
          fs.copyFileSync(sourceFile.path, originalPath);
          const relativePath = getRelativePath(originalPath);
          console.log(`Copied canvaskit file: ${relativePath} <- ${path.basename(sourceFile.path)}`);
        } catch (copyError) {
          console.warn(`Failed to copy canvaskit file ${baseName}: ${copyError.message}`);
        }
      }
    });
  });
}

/**
 * Create copies of asset files (fonts, images, etc.) with original filenames (without hash)
 * This ensures Flutter can find assets by their original names
 * We use file copies instead of symlinks because http-server may not support symlinks
 */
function createFontSymlinks() {
  const doubleAssetsDir = path.join(BUILD_DIR, 'assets', 'assets');
  if (!fs.existsSync(doubleAssetsDir)) {
    return;
  }
  
  console.log('Creating asset file copies for original filenames...');
  
  // Process multiple asset directories
  const assetDirs = ['fonts', 'images', 'icons', 'audio', 'video'];
  
  assetDirs.forEach(dirName => {
    const assetDir = path.join(doubleAssetsDir, dirName);
    if (!fs.existsSync(assetDir)) {
      return;
    }
    
    // Find all asset files in the directory (only real files with extensions, not symlinks)
    const assetFiles = fs.readdirSync(assetDir)
      .filter(f => {
        const fullPath = path.join(assetDir, f);
        try {
          const stat = fs.statSync(fullPath);
          // Only process regular files (not symlinks) with common asset extensions
          return stat.isFile() && /\.(ttf|otf|woff|woff2|png|jpg|jpeg|gif|svg|webp|ico|mp3|wav|ogg|mp4|webm)$/i.test(f);
        } catch (e) {
          return false;
        }
      })
      .map(f => path.join(assetDir, f));
    
    if (assetFiles.length === 0) {
      return;
    }
    
    // Track which original filenames we've already created
    const createdOriginals = new Set();
    
    // Group files by base name (without hash)
    const filesByBaseName = new Map();
    
    assetFiles.forEach(assetPath => {
      const fileName = path.basename(assetPath);
      const extMatch = fileName.match(/\.([^.]+)$/);
      if (!extMatch) {
        return;
      }
      const extension = extMatch[0];
      const nameWithoutExt = fileName.substring(0, fileName.length - extension.length);
      const nameWithoutHash = nameWithoutExt.replace(/(-[a-f0-9]{8})+$/i, '');
      const baseName = nameWithoutHash + extension;
      
      if (!filesByBaseName.has(baseName)) {
        filesByBaseName.set(baseName, []);
      }
      filesByBaseName.get(baseName).push({ path: assetPath, fileName });
    });
    
    // For each base name, create copies for all hash variations
    filesByBaseName.forEach((files, baseName) => {
      // Find the file with the most hashes (likely the most recent/complete one)
      const sortedFiles = files.sort((a, b) => {
        const aHashCount = (a.fileName.match(/-[a-f0-9]{8}/gi) || []).length;
        const bHashCount = (b.fileName.match(/-[a-f0-9]{8}/gi) || []).length;
        return bHashCount - aHashCount;
      });
      const sourceFile = sortedFiles[0];
      
      // Create original filename copy (no hash)
      if (baseName !== sourceFile.fileName && !createdOriginals.has(baseName)) {
        const originalPath = path.join(assetDir, baseName);
        if (fs.existsSync(originalPath)) {
          try {
            const stat = fs.statSync(originalPath);
            if (!stat.isFile() || stat.isSymbolicLink()) {
              fs.unlinkSync(originalPath);
            } else {
              return; // Already exists
            }
          } catch (e) {
            // Ignore errors
          }
        }
        
        try {
          fs.copyFileSync(sourceFile.path, originalPath);
          createdOriginals.add(baseName);
          console.log(`Copied ${dirName} file: ${baseName} <- ${sourceFile.fileName}`);
        } catch (copyError) {
          console.warn(`Failed to copy ${dirName} file ${baseName}: ${copyError.message}`);
        }
      }
      
      // Note: We only create the original filename copy (no hash)
      // Hash variations are handled through AssetManifest mappings
      // This preserves cache effectiveness while ensuring files can be found
    });
  });
}

/**
 * Update AssetManifest files to add original path mappings
 * This ensures google_fonts and other packages can find hashed font files
 */
function updateAssetManifests() {
  const assetsDir = path.join(BUILD_DIR, 'assets');
  if (!fs.existsSync(assetsDir)) {
    return;
  }
  
  // Find all AssetManifest files
  const manifestFiles = fs.readdirSync(assetsDir)
    .filter(f => f.startsWith('AssetManifest') && f.endsWith('.json'))
    .map(f => path.join(assetsDir, f));
  
  const doubleAssetsDir = path.join(BUILD_DIR, 'assets', 'assets');
  const hasDoubleAssets = fs.existsSync(doubleAssetsDir);
  
  manifestFiles.forEach(manifestPath => {
    try {
      const content = fs.readFileSync(manifestPath, 'utf8');
      const manifest = JSON.parse(content);
      let updated = false;
      
      // For each path in the manifest, add mappings for original filenames and hash variations
      Object.keys(manifest).forEach(hashedPath => {
        // Extract original path by removing hash suffixes
        const originalPath = hashedPath.replace(/-[a-f0-9]{8}(-[a-f0-9]{8})*\.([^.]+)$/, '.$1');
        
        // Process all asset files (fonts, images, etc.), not just fonts
        if (originalPath !== hashedPath && /\.(ttf|otf|woff|woff2|png|jpg|jpeg|gif|svg|webp|ico|mp3|wav|ogg|mp4|webm)$/i.test(originalPath)) {
          // Get the current value
          let value = manifest[hashedPath];
          
          // If files are in double assets directory, update the value path
          if (hasDoubleAssets && hashedPath.startsWith('assets/')) {
            const relativePath = hashedPath.substring('assets/'.length);
            const dirPath = path.dirname(relativePath);
            const fileName = path.basename(relativePath);
            const baseFileName = fileName.replace(/-[a-f0-9]{8}(-[a-f0-9]{8})*\.([^.]+)$/, '.$1');
            
            // Find the actual file in double assets directory
            const doubleAssetsAssetDir = path.join(doubleAssetsDir, dirPath);
            if (fs.existsSync(doubleAssetsAssetDir)) {
              const files = fs.readdirSync(doubleAssetsAssetDir);
              // Find file that matches the hashed filename or starts with base filename
              const actualFile = files.find(f => {
                return f === fileName || f.startsWith(baseFileName.replace(/\.[^.]+$/, '-'));
              });
              
              if (actualFile) {
                const actualPath = path.join(dirPath, actualFile).replace(/\\/g, '/');
                value = [`assets/assets/${actualPath}`];
                
                // Update the hashed path value
                if (JSON.stringify(value) !== JSON.stringify(manifest[hashedPath])) {
                  manifest[hashedPath] = value;
                  updated = true;
                }
              }
            }
          }
          
          // Add mapping for original path (single assets)
          if (!manifest[originalPath]) {
            manifest[originalPath] = value;
            updated = true;
            console.log(`Added AssetManifest mapping: ${originalPath} -> ${JSON.stringify(value)}`);
          }
          
          // Add mapping for double assets original path
          if (hasDoubleAssets && originalPath.startsWith('assets/')) {
            const doubleAssetsOriginalPath = `assets/assets/${originalPath.substring('assets/'.length)}`;
            if (!manifest[doubleAssetsOriginalPath]) {
              manifest[doubleAssetsOriginalPath] = value;
              updated = true;
              console.log(`Added AssetManifest mapping: ${doubleAssetsOriginalPath} -> ${JSON.stringify(value)}`);
            }
          }
          
          // Add mappings for intermediate hash variations (e.g., 2 hashes, 3 hashes)
          // Extract hash count from hashedPath
          const hashMatches = hashedPath.match(/(-[a-f0-9]{8})+/gi);
          if (hashMatches && hashMatches.length > 1) {
            // Create mappings for all hash variations (1 hash, 2 hashes, etc.)
            for (let i = 1; i < hashMatches.length; i++) {
              const partialHash = hashMatches.slice(0, i).join('');
              const extMatch = originalPath.match(/\.([^.]+)$/);
              if (!extMatch) continue;
              const extension = extMatch[0];
              const nameWithoutExt = originalPath.substring(0, originalPath.length - extension.length);
              const partialPath = nameWithoutExt + partialHash + extension;
              
              // Only add if it doesn't exist and is different from hashedPath
              if (partialPath !== hashedPath && !manifest[partialPath]) {
                manifest[partialPath] = value;
                updated = true;
                console.log(`Added AssetManifest mapping: ${partialPath} -> ${JSON.stringify(value)}`);
              }
              
              // Also add double assets version
              if (hasDoubleAssets && partialPath.startsWith('assets/')) {
                const doubleAssetsPartialPath = `assets/assets/${partialPath.substring('assets/'.length)}`;
                if (!manifest[doubleAssetsPartialPath]) {
                  manifest[doubleAssetsPartialPath] = value;
                  updated = true;
                  console.log(`Added AssetManifest mapping: ${doubleAssetsPartialPath} -> ${JSON.stringify(value)}`);
                }
              }
            }
          }
        }
      });
      
      if (updated) {
        fs.writeFileSync(manifestPath, JSON.stringify(manifest), 'utf8');
        console.log(`Updated ${path.basename(manifestPath)}`);
      }
    } catch (error) {
      console.warn(`Failed to update ${path.basename(manifestPath)}: ${error.message}`);
    }
  });
}

/**
 * Main optimization process
 */
function optimize() {
  console.log('=== Flutter Web Build Optimizer ===\n');
  
  if (!fs.existsSync(BUILD_DIR)) {
    console.error(`Error: Build directory not found: ${BUILD_DIR}`);
    console.error('Please run "flutter build web" first.');
    process.exit(1);
  }
  
  // Step 1: Split main.dart.js first (if exists) before hashing
  const mainDartJsPath = path.join(BUILD_DIR, 'main.dart.js');
  let chunkInfo = null;
  let loaderPath = null;
  
  if (fs.existsSync(mainDartJsPath)) {
    console.log('Step 1: Splitting main.dart.js...\n');
    chunkInfo = splitMainDartJs(mainDartJsPath);
    loaderPath = createChunkLoader(chunkInfo);
  }
  
  // Step 2: Update flutter_bootstrap.js BEFORE hashing (if chunks were created)
  // This ensures we can find the file by its original name
  if (chunkInfo && loaderPath) {
    console.log('\nStep 2: Updating flutter_bootstrap.js with chunk loader...\n');
    const bootstrapPath = path.join(BUILD_DIR, 'flutter_bootstrap.js');
    if (fs.existsSync(bootstrapPath)) {
      let bootstrapContent = fs.readFileSync(bootstrapPath, 'utf8');
      // Replace mainJsPath reference with temporary loader path
      // We'll update it again after hashing with the final hashed path
      bootstrapContent = bootstrapContent.replace(
        /"mainJsPath"\s*:\s*"main\.dart\.js"/g,
        `"mainJsPath": "${loaderPath}"`
      );
      bootstrapContent = bootstrapContent.replace(
        /mainJsPath\s*:\s*"main\.dart\.js"/g,
        `mainJsPath: "${loaderPath}"`
      );
      fs.writeFileSync(bootstrapPath, bootstrapContent, 'utf8');
      console.log('Updated flutter_bootstrap.js to use chunk loader');
    }
  }
  
  // Step 3: Hash all files (except index.html)
  console.log('\nStep 3: Hashing resource files...\n');
  const allFiles = findAllFiles(BUILD_DIR);
  
  // Hash all files including chunks, loader, and flutter_bootstrap.js
  allFiles.forEach(filePath => {
    hashFile(filePath);
  });
  
  // Step 4: Update chunk loader with hashed chunk paths if chunks were created
  if (chunkInfo && loaderPath) {
    console.log('\nStep 4: Updating chunk loader with hashed paths...\n');
    const hashedChunkFiles = chunkInfo.chunkFiles.map(chunk => {
      return resourceMap.get(chunk) || chunk;
    });
    chunkInfo.chunkFiles = hashedChunkFiles;
    
    // Remove all existing chunk-loader files (including hashed ones)
    const existingLoaders = fs.readdirSync(BUILD_DIR)
      .filter(f => f.startsWith('chunk-loader-main.dart') && f.endsWith('.js'))
      .map(f => path.join(BUILD_DIR, f));
    existingLoaders.forEach(loaderFile => {
      fs.unlinkSync(loaderFile);
      console.log(`Removed old loader: ${path.basename(loaderFile)}`);
    });
    
    // Also remove from resourceMap if it was hashed
    const originalLoaderPath = `chunk-loader-main.dart.js`;
    if (resourceMap.has(originalLoaderPath)) {
      resourceMap.delete(originalLoaderPath);
    }
    // Remove any hashed versions from resourceMap
    Array.from(resourceMap.entries()).forEach(([key, value]) => {
      if (key.includes('chunk-loader-main.dart') || value.includes('chunk-loader-main.dart')) {
        resourceMap.delete(key);
      }
    });
    
    // Create new loader with hashed chunk paths
    loaderPath = createChunkLoader(chunkInfo);
    
    // Hash the new loader
    const newLoaderPath = path.join(BUILD_DIR, loaderPath);
    if (fs.existsSync(newLoaderPath)) {
      hashFile(newLoaderPath);
      loaderPath = resourceMap.get(loaderPath) || loaderPath;
    }
    
    // Find and update the hashed flutter_bootstrap-*.js file
    console.log('\nStep 5: Updating hashed flutter_bootstrap.js...\n');
    const bootstrapFiles = fs.readdirSync(BUILD_DIR)
      .filter(f => f.startsWith('flutter_bootstrap-') && f.endsWith('.js'))
      .map(f => path.join(BUILD_DIR, f));
    
    if (bootstrapFiles.length === 0) {
      console.warn('Warning: No flutter_bootstrap-*.js file found');
    } else {
      bootstrapFiles.forEach(bootstrapPath => {
        let bootstrapContent = fs.readFileSync(bootstrapPath, 'utf8');
        const originalContent = bootstrapContent;
        
        // Update mainJsPath in buildConfig JSON
        // Pattern: "mainJsPath":"chunk-loader-main.dart-xxx.js" or "mainJsPath":"main.dart.js"
        bootstrapContent = bootstrapContent.replace(
          /"mainJsPath"\s*:\s*"[^"]*"/g,
          `"mainJsPath": "${loaderPath}"`
        );
        
        // Also handle minified code without quotes around property name
        bootstrapContent = bootstrapContent.replace(
          /mainJsPath\s*:\s*"[^"]*"/g,
          `mainJsPath: "${loaderPath}"`
        );
        
        // Update entrypointUrl default value if present
        bootstrapContent = bootstrapContent.replace(
          /entrypointUrl\s*:\s*i\s*=\s*l\("main\.dart\.js"\)/g,
          `entrypointUrl: i = l("${loaderPath}")`
        );
        
        // Force use local CanvasKit instead of CDN
        // The T function returns CDN URL when engineRevision exists and useLocalCanvasKit is false
        // We need to force it to return "canvaskit" (local path)
        
        // Pattern 1: Replace the entire ternary expression
        bootstrapContent = bootstrapContent.replace(
          /t\.engineRevision\&\&!t\.useLocalCanvasKit\?C\("https:\/\/www\.gstatic\.com\/flutter-canvaskit",t\.engineRevision\):"canvaskit"/g,
          '"canvaskit"'
        );
        
        // Pattern 2: Replace with different spacing
        bootstrapContent = bootstrapContent.replace(
          /t\.engineRevision\s*\&\&\s*!t\.useLocalCanvasKit\s*\?\s*C\("https:\/\/www\.gstatic\.com\/flutter-canvaskit",\s*t\.engineRevision\)\s*:\s*"canvaskit"/g,
          '"canvaskit"'
        );
        
        // Pattern 3: Replace the function T to always return "canvaskit"
        // function T(n,t){return n.canvasKitBaseUrl?n.canvasKitBaseUrl:t.engineRevision&&!t.useLocalCanvasKit?C("https://www.gstatic.com/flutter-canvaskit",t.engineRevision):"canvaskit"}
        bootstrapContent = bootstrapContent.replace(
          /function T\([^)]*\)\{[^}]*return[^}]*\?[^}]*C\("https:\/\/www\.gstatic\.com\/flutter-canvaskit"[^}]*:"canvaskit"[^}]*\}/g,
          'function T(n,t){return n.canvasKitBaseUrl?n.canvasKitBaseUrl:"canvaskit"}'
        );
        
        // Pattern 4: More aggressive - replace any CDN URL construction
        bootstrapContent = bootstrapContent.replace(
          /C\("https:\/\/www\.gstatic\.com\/flutter-canvaskit"[^)]*\)/g,
          '"canvaskit"'
        );
        
        if (bootstrapContent !== originalContent) {
          fs.writeFileSync(bootstrapPath, bootstrapContent, 'utf8');
          console.log(`Updated ${path.basename(bootstrapPath)} with hashed loader path: ${loaderPath}`);
        } else {
          console.log(`No changes needed for ${path.basename(bootstrapPath)}`);
        }
      });
    }
  }
  
  // Step 6: Create copies for original canvaskit filenames
  console.log('\nStep 6: Creating canvaskit original file copies...\n');
  createCanvaskitOriginals();
  
  // Step 7: Create symlinks for original font filenames
  console.log('\nStep 7: Creating font symlinks...\n');
  createFontSymlinks();
  
  // Step 8: Update AssetManifest files to map original paths to hashed paths
  console.log('\nStep 8: Updating AssetManifest files...\n');
  updateAssetManifests();
  
  // Step 9: Update all file references (only critical files for performance)
  console.log('\nStep 9: Updating file references...\n');
  const filesToUpdate = findAllFiles(BUILD_DIR);
  
  /**
   * Load dependency version cache from disk
   */
  function loadDependencyVersionCache() {
    try {
      if (fs.existsSync(DEPENDENCY_VERSION_CACHE_FILE)) {
        const cacheContent = fs.readFileSync(DEPENDENCY_VERSION_CACHE_FILE, 'utf8');
        dependencyVersionCache = JSON.parse(cacheContent);
        console.log(`Loaded dependency version cache (${Object.keys(dependencyVersionCache).length} entries)`);
      }
    } catch (error) {
      console.warn(`Warning: Failed to load dependency version cache: ${error.message}`);
      dependencyVersionCache = {};
    }
  }
  
  /**
   * Save dependency version cache to disk
   */
  function saveDependencyVersionCache() {
    try {
      fs.writeFileSync(DEPENDENCY_VERSION_CACHE_FILE, JSON.stringify(dependencyVersionCache, null, 2), 'utf8');
    } catch (error) {
      console.warn(`Warning: Failed to save dependency version cache: ${error.message}`);
    }
  }
  
  /**
   * Extract version signature from dependency file
   * For Flutter files: extract first hash (e.g., "flutter-76f08d47-..." -> "76f08d47")
   * For CanvasKit files: extract first hash from filename
   */
  function extractDependencyVersion(filePath) {
    const baseName = path.basename(filePath);
    const relativePath = getRelativePath(filePath);
    
    // Extract version from filename hash pattern
    // Pattern: name-version-hash-hash.ext or name-version.ext
    const hashPattern = /-([a-f0-9]{8})(?:-|\.)/i;
    const match = baseName.match(hashPattern);
    
    if (match) {
      return match[1]; // Return first 8-char hash as version identifier
    }
    
    // Fallback: use file content hash as version
    try {
      const stats = fs.statSync(filePath);
      // Use file size + modification time as version for very large files
      if (stats.size > 5 * 1024 * 1024) {
        return `${stats.size}-${stats.mtimeMs}`;
      }
      // For smaller files, use content hash
      return calculateHash(filePath);
    } catch (error) {
      return null;
    }
  }
  
  /**
   * Check if a file is a dependency file (third-party library/framework)
   * These files typically don't need reference updates and can be cached
   */
  function isDependencyFile(filePath) {
    const relativePath = getRelativePath(filePath);
    const baseName = path.basename(filePath);
    const dirName = path.dirname(relativePath);
    
    // CanvasKit files (Flutter engine - rarely changes)
    if (dirName.startsWith('canvaskit/') || relativePath.startsWith('canvaskit/')) {
      return true;
    }
    
    // Flutter framework files (flutter-*.js - framework code, not app code)
    if (baseName.startsWith('flutter-') && baseName.endsWith('.js') && 
        !baseName.includes('bootstrap') && !baseName.includes('service_worker')) {
      return true;
    }
    
    // Other third-party library patterns can be added here
    // For example: vendor/, lib/, node_modules/, etc.
    
    return false;
  }
  
  /**
   * Check if dependency file has changed version
   * Returns true if version changed or file is new, false if unchanged
   */
  function hasDependencyVersionChanged(filePath) {
    const relativePath = getRelativePath(filePath);
    const currentVersion = extractDependencyVersion(filePath);
    
    if (!currentVersion) {
      return true; // If we can't determine version, process it
    }
    
    const cachedVersion = dependencyVersionCache[relativePath];
    
    if (!cachedVersion) {
      // New file, needs processing
      dependencyVersionCache[relativePath] = currentVersion;
      return true;
    }
    
    if (cachedVersion !== currentVersion) {
      // Version changed, needs processing
      dependencyVersionCache[relativePath] = currentVersion;
      return true;
    }
    
    // Version unchanged, can skip
    return false;
  }
  
  // Load dependency version cache at start
  loadDependencyVersionCache();
  
  // Filter to only critical files that need reference updates
  // Skip dependency files (they don't contain references to app files)
  // Skip most JS files as they're already processed or don't need updates
  const criticalFiles = filesToUpdate.filter(filePath => {
    // Check dependency files - only process if version changed
    if (isDependencyFile(filePath)) {
      // Only process if version changed, otherwise skip (can use cached version)
      return hasDependencyVersionChanged(filePath);
    }
    
    const ext = getExtension(filePath).toLowerCase();
    const baseName = path.basename(filePath);
    const relativePath = getRelativePath(filePath);
    
    // Always update: HTML, CSS, JSON files (app configuration files)
    if (['.html', '.css', '.json'].includes(ext)) {
      return true;
    }
    
    // Only update specific JS files: bootstrap, chunk loader, service workers, app chunks
    if (ext === '.js') {
      return baseName.startsWith('flutter_bootstrap') ||
             baseName.startsWith('chunk-loader') ||
             baseName.startsWith('flutter_service_worker') ||
             baseName.startsWith('main.dart-chunk');
    }
    
    return false;
  });
  
  // Pre-filter resourceMap to only include mappings that are likely to be referenced
  // This reduces the search space for each file update
  const relevantResourceMap = new Map();
  const criticalFileNames = new Set(criticalFiles.map(f => path.basename(f).toLowerCase()));
  const criticalDirs = new Set(criticalFiles.map(f => path.dirname(getRelativePath(f))));
  
  resourceMap.forEach((hashedPath, originalPath) => {
    const originalBase = path.basename(originalPath).toLowerCase();
    const originalDir = path.dirname(originalPath);
    
    // Include if:
    // 1. Filename matches any critical file (likely referenced)
    // 2. Directory matches any critical file directory
    // 3. It's a common asset type (fonts, images, etc.)
    if (criticalFileNames.has(originalBase) ||
        criticalDirs.has(originalDir) ||
        /\.(ttf|otf|woff|woff2|png|jpg|jpeg|gif|svg|webp|ico|json|js|wasm|bin)$/i.test(originalPath)) {
      relevantResourceMap.set(originalPath, hashedPath);
    }
  });
  
  console.log(`Filtered resource map: ${relevantResourceMap.size} relevant mappings (out of ${resourceMap.size} total)`);
  
  // Count dependency files for reporting (check versions without modifying cache)
  const dependencyFiles = filesToUpdate.filter(isDependencyFile);
  let changedCount = 0;
  let unchangedCount = 0;
  
  dependencyFiles.forEach(filePath => {
    const relativePath = getRelativePath(filePath);
    const currentVersion = extractDependencyVersion(filePath);
    const cachedVersion = dependencyVersionCache[relativePath];
    
    if (!cachedVersion || cachedVersion !== currentVersion) {
      changedCount++;
      // Update cache
      if (currentVersion) {
        dependencyVersionCache[relativePath] = currentVersion;
      }
    } else {
      unchangedCount++;
    }
  });
  
  if (dependencyFiles.length > 0) {
    console.log(`Dependency files: ${changedCount} changed (will process), ${unchangedCount} unchanged (skipped - using cache)`);
  }
  
  console.log(`Found ${criticalFiles.length} critical files to update (out of ${filesToUpdate.length} total files)`);
  let processed = 0;
  let updated = 0;
  let skipped = 0;
  let alreadyProcessed = 0;
  const startTime = Date.now();
  
  // Use filtered resource map for better performance
  const mapToUse = relevantResourceMap.size > 0 ? relevantResourceMap : resourceMap;
  
  criticalFiles.forEach((filePath, index) => {
    const baseName = path.basename(filePath);
    const relativePath = getRelativePath(filePath);
    
    // Show current file being processed every 10 files or for important files
    if (processed % 10 === 0 || baseName.startsWith('flutter_bootstrap') || 
        baseName.startsWith('flutter_service_worker') || baseName === 'index.html') {
      process.stdout.write(`\r  Progress: ${processed}/${criticalFiles.length} (${Math.round(processed/criticalFiles.length*100)}%) - Processing: ${baseName.substring(0, 40)}...`);
    }
    
    try {
      const wasUpdated = updateFileReferences(filePath, mapToUse);
      processed++;
      if (wasUpdated) {
        updated++;
      } else {
        alreadyProcessed++;
      }
    } catch (error) {
      skipped++;
      console.warn(`\n⚠️  Skipped file: ${relativePath} - ${error.message}`);
    }
    
    // Show progress every 20 files (reduced frequency for better performance)
    if (processed % 20 === 0) {
      const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
      const rate = (processed / elapsed).toFixed(1);
      process.stdout.write(`\r  Progress: ${processed}/${criticalFiles.length} (${Math.round(processed/criticalFiles.length*100)}%) - ${rate} files/sec`);
    }
  });
  
  if (processed > 0 || skipped > 0) {
    const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
    console.log(`\n  Completed: ${updated} files updated, ${alreadyProcessed} already processed (skipped), ${skipped} failed (${elapsed}s)`);
  }
  
  // Step 9.1: Update index.html references (including explicit bootstrap and manifest updates)
  console.log('\nStep 9.1: Updating index.html references...\n');
  const indexPath = path.join(BUILD_DIR, INDEX_HTML);
  updateFileReferences(indexPath);
  
  // Explicitly update flutter_bootstrap.js and manifest.json references in index.html
  // These are critical entry points that must be updated correctly
  let indexContent = fs.readFileSync(indexPath, 'utf8');
  const originalIndexContent = indexContent;
  
  // Find the actual hashed flutter_bootstrap file
  const bootstrapFiles = fs.readdirSync(BUILD_DIR)
    .filter(f => f.startsWith('flutter_bootstrap-') && f.endsWith('.js'))
    .map(f => path.basename(f));
  
  if (bootstrapFiles.length > 0) {
    indexContent = indexContent.replace(
      /<script[^>]*src=["']flutter_bootstrap\.js["'][^>]*>/i,
      `<script src="${bootstrapFiles[0]}" async></script>`
    );
  }
  
  // Find the actual hashed manifest file (use the shortest one, which is usually the base manifest)
  const manifestFiles = fs.readdirSync(BUILD_DIR)
    .filter(f => f.startsWith('manifest-') && f.endsWith('.json'))
    .map(f => path.basename(f))
    .sort((a, b) => a.length - b.length);
  
  if (manifestFiles.length > 0) {
    indexContent = indexContent.replace(
      /<link[^>]*rel=["']manifest["'][^>]*href=["']manifest\.json["'][^>]*>/i,
      `<link rel="manifest" href="${manifestFiles[0]}">`
    );
  }
  
  if (indexContent !== originalIndexContent) {
    fs.writeFileSync(indexPath, indexContent, 'utf8');
    console.log(`Updated ${INDEX_HTML} with hashed file references`);
  }
  
  // Step 9.2: Fix CanvasKit paths - create chromium subdirectory if needed
  console.log('\nStep 9.2: Fixing CanvasKit paths...\n');
  const canvaskitDir = path.join(BUILD_DIR, 'canvaskit');
  const canvaskitChromiumDir = path.join(canvaskitDir, 'chromium');
  
  if (fs.existsSync(canvaskitDir) && !fs.existsSync(canvaskitChromiumDir)) {
    fs.mkdirSync(canvaskitChromiumDir, { recursive: true });
    console.log('Created canvaskit/chromium directory');
  }
  
  // Copy or link CanvasKit files to chromium subdirectory if they're referenced there
  if (fs.existsSync(canvaskitDir)) {
    const canvaskitFiles = fs.readdirSync(canvaskitDir)
      .filter(f => {
        const fullPath = path.join(canvaskitDir, f);
        try {
          return fs.statSync(fullPath).isFile() && 
                 (f.endsWith('.wasm') || f.endsWith('.js'));
        } catch {
          return false;
        }
      });
    
    canvaskitFiles.forEach(file => {
      const sourcePath = path.join(canvaskitDir, file);
      const targetPath = path.join(canvaskitChromiumDir, file);
      
      // Only create if doesn't exist
      if (!fs.existsSync(targetPath)) {
        try {
          fs.copyFileSync(sourcePath, targetPath);
          console.log(`Copied CanvasKit file to chromium/: ${file}`);
        } catch (error) {
          console.warn(`Failed to copy ${file} to chromium/: ${error.message}`);
        }
      }
    });
  }
  
  // Step 10: Update Service Worker files and optimize activation
  console.log('\nStep 10: Updating Service Worker files...\n');
  const serviceWorkerFiles = fs.readdirSync(BUILD_DIR)
    .filter(f => f.startsWith('flutter_service_worker-') && f.endsWith('.js'))
    .map(f => path.join(BUILD_DIR, f));
  
  console.log(`Found ${serviceWorkerFiles.length} Service Worker files to update...`);
  let swProcessed = 0;
  serviceWorkerFiles.forEach(swPath => {
    let swContent = fs.readFileSync(swPath, 'utf8');
    const originalContent = swContent;
    
    // IMPORTANT: In Service Worker, manifest.json() is a method call on a variable (Response object)
    // Pattern: var manifest = await manifestCache.match('manifest');
    //          var oldManifest = await manifest.json();  // manifest is a variable, not a filename
    // We must restore this to the correct form: await manifest.json()
    
    // Fix incorrectly replaced variable method calls
    // Pattern 1: Fix await manifest_xxx_json.json() back to await manifest.json()
    // This happens when manifest.json() was incorrectly treated as a filename
    swContent = swContent.replace(
      /await\s+manifest_[a-f0-9_]+\.json\(\)/g,
      'await manifest.json()'
    );
    
    // Pattern 2: Fix await "manifest-xxx.json" (string) back to await manifest.json() (variable method call)
    // This happens when it was replaced as a string literal
    swContent = swContent.replace(
      /(var\s+oldManifest\s*=\s*await\s+)["']([a-zA-Z0-9_-]+-[a-f0-9]+(?:-[a-f0-9]+)*\.json)["']/g,
      (match, prefix) => {
        // This should be await manifest.json() where manifest is a variable
        return prefix + 'manifest.json()';
      }
    );
    
    // Pattern 3: Fix any await "manifest-xxx.json" that appears in context of manifest variable
    swContent = swContent.replace(
      /(var\s+manifest\s*=.*?manifestCache\.match\(['"]manifest['"]\)[^;]*;\s*[^}]*?await\s+)["']([a-zA-Z0-9_-]+-[a-f0-9]+(?:-[a-f0-9]+)*\.json)["']/gs,
      (match, prefix) => {
        // If this is after a manifest variable assignment, it should be manifest.json()
        return prefix + 'manifest.json()';
      }
    );
    
    // Optimize: Skip immediate cache cleanup on first install to speed up activation
    swContent = swContent.replace(
      /if \(!manifest\) \{[^}]*await caches\.delete\(CACHE_NAME\);[^}]*contentCache = await caches\.open\(CACHE_NAME\);/gs,
      `if (!manifest) {
        // Skip cache deletion on first install for faster activation
        contentCache = await caches.open(CACHE_NAME);`
    );
    
    // Fix: Replace addAll with individual add calls to handle failures gracefully
    // addAll fails if ANY resource fails, so we need to add them individually
    swContent = swContent.replace(
      /return contentCache\.addAll\(resources\);/g,
      `// Add resources individually to handle failures gracefully
  var addPromises = resources.map(function(resource) {
    return contentCache.add(new Request(resource, {'cache': 'reload'})).catch(function(err) {
      console.warn('Failed to cache resource: ' + resource + ', error: ' + err);
      return null; // Continue even if one resource fails
    });
  });
  return Promise.all(addPromises);`
    );
    
    // Also fix the install event addAll
    swContent = swContent.replace(
      /return cache\.addAll\(\s*CORE\.map\(\(value\) => new Request\(value, \{'cache': 'reload'\}\)\)\s*\);/g,
      `// Add CORE resources individually to handle failures gracefully
  var corePromises = CORE.map(function(value) {
    return cache.add(new Request(value, {'cache': 'reload'})).catch(function(err) {
      console.warn('Failed to cache CORE resource: ' + value + ', error: ' + err);
      return null; // Continue even if one resource fails
    });
  });
  return Promise.all(corePromises);`
    );
    
    // Now update other references normally (but skip variable method calls)
    // Use full resource map for service workers as they reference many files
    swContent = updateReferences(swContent, swPath, resourceMap);
    
    // Final fix: Ensure manifest.json() is not replaced again
    swContent = swContent.replace(
      /await\s+manifest_[a-f0-9_]+\.json\(\)/g,
      'await manifest.json()'
    );
    
    if (swContent !== originalContent) {
      fs.writeFileSync(swPath, swContent, 'utf8');
      console.log(`Updated Service Worker: ${path.basename(swPath)}`);
    }
    swProcessed++;
    if (swProcessed % 5 === 0 || swProcessed === serviceWorkerFiles.length) {
      process.stdout.write(`\r  Progress: ${swProcessed}/${serviceWorkerFiles.length} Service Workers`);
    }
  });
  if (serviceWorkerFiles.length > 0) {
    console.log(`\n  Completed: ${serviceWorkerFiles.length} Service Workers processed`);
  }
  
  // Save dependency version cache before exit
  saveDependencyVersionCache();
  
  console.log('\n=== Optimization Complete ===');
  console.log(`Total files hashed: ${resourceMap.size}`);
  if (chunkInfo) {
    console.log(`Main file split into ${chunkInfo.chunkCount} chunks`);
  }
  console.log(`Dependency version cache saved (${Object.keys(dependencyVersionCache).length} entries)`);
}

// Run optimization
optimize();

