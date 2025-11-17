import { convert, hexToRGB, sRGB, OKHSL } from "@texel/color";

function isLight(color) {
  let [_h, _s, l] = convert(hexToRGB(color), sRGB, OKHSL);
  return l > 0.5;
}

const VERTEX_SHADER_SOURCE = `#version 300 es\nprecision highp float;\nin vec2 aPosition;\nout vec2 vUV;\nvoid main() {\n  vUV = aPosition * 0.5 + 0.5;\n  gl_Position = vec4(aPosition, 0.0, 1.0);\n}\n`;

const FRAGMENT_SHADER_SOURCE = `#version 300 es
precision highp float;
in vec2 vUV;
out vec4 outColor;

uniform sampler2D uBoardTex;
uniform sampler2D uBrushTex;
uniform sampler2D uTileTex;
uniform ivec2 uGridSize;
uniform ivec2 uBrushSize;
uniform ivec2 uBrushCenter;
uniform ivec2 uTileSize;
uniform vec4 uBackgroundColor;
uniform bool uHasHover;
uniform ivec2 uHoverCell;
uniform bool uUseTileMask;
uniform bool uShowOverlay;
uniform bool uIsSilhouette;
uniform int uOverlayMode;
uniform vec4 uOverlayColorOverride;

float luminance(vec3 color) {
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
  
}

vec2 texCoordFromCell(ivec2 cell, ivec2 gridSize) {
    return vec2(
      (float(cell.x) + 0.5) / float(gridSize.x),
      1.0 - (float(cell.y) + 0.5) / float(gridSize.y)
  );
  
}

void main() {
    ivec2 gridSize = uGridSize;
    if (gridSize.x <= 0 || gridSize.y <= 0) {
      outColor = vec4(0.0, 0.0, 0.0, 0.0);
      return;
  
  }

  ivec2 cell;
  cell.x = int(floor(vUV.x * float(gridSize.x)));
  cell.y = int(floor((1.0 - vUV.y) * float(gridSize.y)));

  if (cell.x < 0 || cell.x >= gridSize.x || cell.y < 0 || cell.y >= gridSize.y) {
      outColor = vec4(0.0, 0.0, 0.0, 0.0);
      return;
  
  }

  vec2 cellCoord = texCoordFromCell(cell, gridSize);
  vec4 cellData = texture(uBoardTex, cellCoord);
  float hasFill = cellData.a;
  vec3 baseColor = cellData.rgb;
  float baseAlpha = hasFill;

  float overlayAlpha = 0.0;
  vec3 overlayColor = vec3(1.0);
  bool colorSet = false;

  if (uShowOverlay && uHasHover) {
      ivec2 brushCoord = cell - uHoverCell + uBrushCenter;
      bool brushAllows = false;
  
      if (brushCoord.x >= 0 && brushCoord.x < uBrushSize.x && brushCoord.y >= 0 && brushCoord.y < uBrushSize.y) {
        vec2 brushUv = texCoordFromCell(brushCoord, uBrushSize);
        brushAllows = texture(uBrushTex, brushUv).r > 0.5;
  
    }

    bool maskAllows = true;
    if (uUseTileMask && uTileSize.x > 0 && uTileSize.y > 0) {
        int maskX = int(mod(float(cell.x), float(uTileSize.x)));
        int maskY = int(mod(float(cell.y), float(uTileSize.y)));
        ivec2 maskCell = ivec2(maskX, maskY);
        vec2 tileUv = texCoordFromCell(maskCell, uTileSize);
        maskAllows = texture(uTileTex, tileUv).r > 0.5;
  
    }

    if (brushAllows && maskAllows) {
      if (uOverlayMode == 2) {
        outColor = uOverlayColorOverride;
        colorSet = true;
      } else {
        vec3 referenceColor = baseAlpha > 0.0 ? baseColor : uBackgroundColor.rgb;
        float testL = luminance(referenceColor);
        overlayColor = testL > 0.5 ? vec3(0.0) : vec3(1.0);
        overlayAlpha = 0.2;
      }
    }
  }

  if (!colorSet) {
    vec3 colorAfterOverlay = mix(baseColor, overlayColor, overlayAlpha);
    vec3 finalColor = mix(overlayColor, colorAfterOverlay, baseAlpha);
    float finalAlpha = max(baseAlpha, overlayAlpha);
    outColor = vec4(finalColor, finalAlpha);
  }
}
`;

function compileShader(gl, type, source) {
  const shader = gl.createShader(type);
  if (!shader) {
    throw new Error("Failed to create shader");
  }
  gl.shaderSource(shader, source);
  gl.compileShader(shader);
  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
    const info = gl.getShaderInfoLog(shader);
    gl.deleteShader(shader);
    throw new Error(`Shader compile error: ${info || "unknown error"}`);
  }
  return shader;
}

function createProgram(gl, vertexSource, fragmentSource) {
  const vertexShader = compileShader(gl, gl.VERTEX_SHADER, vertexSource);
  const fragmentShader = compileShader(gl, gl.FRAGMENT_SHADER, fragmentSource);
  const program = gl.createProgram();
  if (!program) {
    throw new Error("Failed to create program");
  }
  gl.attachShader(program, vertexShader);
  gl.attachShader(program, fragmentShader);
  gl.linkProgram(program);
  if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
    const info = gl.getProgramInfoLog(program);
    gl.deleteProgram(program);
    gl.deleteShader(vertexShader);
    gl.deleteShader(fragmentShader);
    throw new Error(`Program link error: ${info || "unknown error"}`);
  }
  gl.detachShader(program, vertexShader);
  gl.detachShader(program, fragmentShader);
  gl.deleteShader(vertexShader);
  gl.deleteShader(fragmentShader);
  return program;
}

function parseHexColor(color, fallback) {
  if (typeof color !== "string") {
    return fallback;
  }
  let hex = color.trim();
  if (hex.startsWith("#")) {
    hex = hex.slice(1);
  }
  if (hex.length === 3) {
    const r = parseInt(hex[0] + hex[0], 16);
    const g = parseInt(hex[1] + hex[1], 16);
    const b = parseInt(hex[2] + hex[2], 16);
    return [r, g, b];
  }
  if (hex.length === 6 || hex.length === 8) {
    const r = parseInt(hex.slice(0, 2), 16);
    const g = parseInt(hex.slice(2, 4), 16);
    const b = parseInt(hex.slice(4, 6), 16);
    if (Number.isNaN(r) || Number.isNaN(g) || Number.isNaN(b)) {
      return fallback;
    }
    return [r, g, b];
  }
  return fallback;
}

class CanvasRenderer {
  constructor(canvas) {
    this.canvas = canvas;
    const gl = canvas.getContext("webgl2", {
      antialias: false,
      premultipliedAlpha: false,
    });
    if (!gl) {
      throw new Error("WebGL2 not available");
    }
    this.gl = gl;
    this.program = createProgram(
      gl,
      VERTEX_SHADER_SOURCE,
      FRAGMENT_SHADER_SOURCE
    );
    this.uniforms = {};
    this.boardTexture = null;
    this.brushTexture = null;
    this.tileTexture = null;
    this.cols = 0;
    this.rows = 0;
    this.overlayEnabled = true;
    this.isSilhouette = false;
    this.backgroundColor = [1, 1, 1, 1];
    this.currentHover = null;
    this._initGL();
  }

  _initGL() {
    const { gl, program } = this;
    gl.useProgram(program);
    gl.pixelStorei(gl.UNPACK_ALIGNMENT, 1);

    const positionLocation = gl.getAttribLocation(program, "aPosition");
    const positionBuffer = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer);
    gl.bufferData(
      gl.ARRAY_BUFFER,
      new Float32Array([-1, -1, 1, -1, -1, 1, 1, -1, 1, 1, -1, 1]),
      gl.STATIC_DRAW
    );
    gl.enableVertexAttribArray(positionLocation);
    gl.vertexAttribPointer(positionLocation, 2, gl.FLOAT, false, 0, 0);

    this.uniforms = {
      boardTex: gl.getUniformLocation(program, "uBoardTex"),
      brushTex: gl.getUniformLocation(program, "uBrushTex"),
      tileTex: gl.getUniformLocation(program, "uTileTex"),
      gridSize: gl.getUniformLocation(program, "uGridSize"),
      brushSize: gl.getUniformLocation(program, "uBrushSize"),
      brushCenter: gl.getUniformLocation(program, "uBrushCenter"),
      tileSize: gl.getUniformLocation(program, "uTileSize"),
      backgroundColor: gl.getUniformLocation(program, "uBackgroundColor"),
      hasHover: gl.getUniformLocation(program, "uHasHover"),
      hoverCell: gl.getUniformLocation(program, "uHoverCell"),
      useTileMask: gl.getUniformLocation(program, "uUseTileMask"),
      showOverlay: gl.getUniformLocation(program, "uShowOverlay"),
      isSilhouette: gl.getUniformLocation(program, "uIsSilhouette"),
      overlayMode: gl.getUniformLocation(program, "uOverlayMode"),
      overlayColorOverride: gl.getUniformLocation(
        program,
        "uOverlayColorOverride"
      ),
    };

    gl.uniform1i(this.uniforms.boardTex, 0);
    gl.uniform1i(this.uniforms.brushTex, 1);
    gl.uniform1i(this.uniforms.tileTex, 2);
    gl.uniform2i(this.uniforms.gridSize, 0, 0);
    gl.uniform2i(this.uniforms.brushSize, 1, 1);
    gl.uniform2i(this.uniforms.brushCenter, 0, 0);
    gl.uniform2i(this.uniforms.tileSize, 1, 1);
    gl.uniform4f(this.uniforms.backgroundColor, 1, 1, 1, 1);
    gl.uniform1i(this.uniforms.hasHover, 0);
    gl.uniform2i(this.uniforms.hoverCell, 0, 0);
    gl.uniform1i(this.uniforms.useTileMask, 0);
    gl.uniform1i(this.uniforms.showOverlay, 1);
    gl.uniform1i(this.uniforms.isSilhouette, 0);
    if (this.uniforms.overlayMode != null) {
      gl.uniform1i(this.uniforms.overlayMode, 1);
    }
    if (this.uniforms.overlayColorOverride != null) {
      gl.uniform4f(this.uniforms.overlayColorOverride, 1, 1, 1, 1);
    }

    this.boardTexture = gl.createTexture();
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, this.boardTexture);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.texImage2D(
      gl.TEXTURE_2D,
      0,
      gl.RGBA,
      1,
      1,
      0,
      gl.RGBA,
      gl.UNSIGNED_BYTE,
      new Uint8Array([0, 0, 0, 0])
    );

    this.brushTexture = gl.createTexture();
    gl.activeTexture(gl.TEXTURE1);
    gl.bindTexture(gl.TEXTURE_2D, this.brushTexture);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.texImage2D(
      gl.TEXTURE_2D,
      0,
      gl.RGBA,
      1,
      1,
      0,
      gl.RGBA,
      gl.UNSIGNED_BYTE,
      new Uint8Array([0, 0, 0, 0])
    );

    this.tileTexture = gl.createTexture();
    gl.activeTexture(gl.TEXTURE2);
    gl.bindTexture(gl.TEXTURE_2D, this.tileTexture);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.texImage2D(
      gl.TEXTURE_2D,
      0,
      gl.RGBA,
      1,
      1,
      0,
      gl.RGBA,
      gl.UNSIGNED_BYTE,
      new Uint8Array([255, 255, 255, 255])
    );
  }

  setSize(cols, rows, cellSize) {
    const width = Math.max(1, cols * cellSize);
    const height = Math.max(1, rows * cellSize);
    const dpr =
      typeof window !== "undefined" ? window.devicePixelRatio || 1 : 1;
    this.canvas.style.width = `${width}px`;
    this.canvas.style.height = `${height}px`;
    this.canvas.width = Math.max(1, Math.floor(width * dpr));
    this.canvas.height = Math.max(1, Math.floor(height * dpr));
    this.gl.viewport(0, 0, this.canvas.width, this.canvas.height);
  }

  updateBoard(board, backgroundColor, isSilhouette) {
    const backgroundColorIsLight = isLight(backgroundColor);

    const isTypedBoard =
      board &&
      typeof board === "object" &&
      Number.isInteger(board.rows) &&
      Number.isInteger(board.cols) &&
      board.data instanceof Uint32Array;
    const rows = isTypedBoard
      ? Math.max(0, board.rows | 0)
      : Array.isArray(board)
      ? board.length
      : 0;
    const cols =
      rows > 0
        ? isTypedBoard
          ? Math.max(0, board.cols | 0)
          : Array.isArray(board?.[0])
          ? board[0].length
          : 0
        : 0;
    this.rows = rows;
    this.cols = cols;
    this.isSilhouette = Boolean(isSilhouette);

    const bg = parseHexColor(backgroundColor, [255, 255, 255]);
    this.backgroundColor = [bg[0] / 255, bg[1] / 255, bg[2] / 255, 1];

    const { gl } = this;
    gl.useProgram(this.program);
    gl.uniform4f(
      this.uniforms.backgroundColor,
      this.backgroundColor[0],
      this.backgroundColor[1],
      this.backgroundColor[2],
      1
    );
    gl.uniform1i(this.uniforms.isSilhouette, this.isSilhouette ? 1 : 0);
    gl.uniform2i(this.uniforms.gridSize, cols, rows);

    if (cols === 0 || rows === 0) {
      gl.activeTexture(gl.TEXTURE0);
      gl.bindTexture(gl.TEXTURE_2D, this.boardTexture);
      gl.texImage2D(
        gl.TEXTURE_2D,
        0,
        gl.RGBA,
        1,
        1,
        0,
        gl.RGBA,
        gl.UNSIGNED_BYTE,
        new Uint8Array([0, 0, 0, 0])
      );
      return;
    }

    const data = new Uint8Array(cols * rows * 4);
    if (isTypedBoard) {
      const source = board.data;
      for (let row = 0; row < rows; row += 1) {
        const flippedRow = rows - 1 - row;
        for (let col = 0; col < cols; col += 1) {
          const idx = (flippedRow * cols + col) * 4;
          const sourceIdx = row * cols + col;
          const value = source[sourceIdx] >>> 0;
          if (value !== 0) {
            if (this.isSilhouette) {
              data[idx] = 0;
              data[idx + 1] = 0;
              data[idx + 2] = 0;
              if (backgroundColorIsLight) {
                data[idx] = 0;
                data[idx + 1] = 0;
                data[idx + 2] = 0;
              } else {
                data[idx] = 255;
                data[idx + 1] = 255;
                data[idx + 2] = 255;
              }
            } else {
              data[idx] = (value >> 16) & 0xff;
              data[idx + 1] = (value >> 8) & 0xff;
              data[idx + 2] = value & 0xff;
            }
            data[idx + 3] = 255;
          } else {
            data[idx] = 0;
            data[idx + 1] = 0;
            data[idx + 2] = 0;
            data[idx + 3] = 0;
          }
        }
      }
    } else {
      for (let row = 0; row < rows; row += 1) {
        const line = board[row] || [];
        const flippedRow = rows - 1 - row;
        for (let col = 0; col < cols; col += 1) {
          const idx = (flippedRow * cols + col) * 4;
          const cell = line[col];
          if (cell != null) {
            const color = this.isSilhouette
              ? [0, 0, 0]
              : parseHexColor(cell, bg);
            data[idx] = color[0];
            data[idx + 1] = color[1];
            data[idx + 2] = color[2];
            data[idx + 3] = 255;
          } else {
            data[idx] = 0;
            data[idx + 1] = 0;
            data[idx + 2] = 0;
            data[idx + 3] = 0;
          }
        }
      }
    }

    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, this.boardTexture);
    gl.texImage2D(
      gl.TEXTURE_2D,
      0,
      gl.RGBA,
      cols,
      rows,
      0,
      gl.RGBA,
      gl.UNSIGNED_BYTE,
      data
    );
  }

  updateBrush(brush, centerRow, centerCol) {
    const rows = Array.isArray(brush) ? brush.length : 0;
    const cols = rows > 0 && Array.isArray(brush[0]) ? brush[0].length : 0;
    const { gl } = this;
    gl.useProgram(this.program);
    gl.uniform2i(this.uniforms.brushSize, cols, rows);
    gl.uniform2i(this.uniforms.brushCenter, centerCol | 0, centerRow | 0);

    gl.activeTexture(gl.TEXTURE1);
    gl.bindTexture(gl.TEXTURE_2D, this.brushTexture);

    if (cols === 0 || rows === 0) {
      gl.texImage2D(
        gl.TEXTURE_2D,
        0,
        gl.RGBA,
        1,
        1,
        0,
        gl.RGBA,
        gl.UNSIGNED_BYTE,
        new Uint8Array([0, 0, 0, 0])
      );
      return;
    }

    const data = new Uint8Array(cols * rows * 4);
    for (let row = 0; row < rows; row += 1) {
      const line = brush[row] || [];
      for (let col = 0; col < cols; col += 1) {
        const flippedRow = rows - 1 - row;
        const idx = (flippedRow * cols + col) * 4;
        const value = line[col] ? 255 : 0;
        data[idx] = value;
        data[idx + 1] = value;
        data[idx + 2] = value;
        data[idx + 3] = 255;
      }
    }

    gl.texImage2D(
      gl.TEXTURE_2D,
      0,
      gl.RGBA,
      cols,
      rows,
      0,
      gl.RGBA,
      gl.UNSIGNED_BYTE,
      data
    );
  }

  updateTileMask(tileMask) {
    const rows = Array.isArray(tileMask) ? tileMask.length : 0;
    const cols =
      rows > 0 && Array.isArray(tileMask[0]) ? tileMask[0].length : 0;
    const { gl } = this;
    gl.useProgram(this.program);
    gl.uniform2i(this.uniforms.tileSize, cols, rows);
    gl.uniform1i(this.uniforms.useTileMask, cols > 0 && rows > 0 ? 1 : 0);

    gl.activeTexture(gl.TEXTURE2);
    gl.bindTexture(gl.TEXTURE_2D, this.tileTexture);

    if (cols === 0 || rows === 0) {
      gl.texImage2D(
        gl.TEXTURE_2D,
        0,
        gl.RGBA,
        1,
        1,
        0,
        gl.RGBA,
        gl.UNSIGNED_BYTE,
        new Uint8Array([255, 255, 255, 255])
      );
      return;
    }

    const data = new Uint8Array(cols * rows * 4);
    for (let row = 0; row < rows; row += 1) {
      const line = tileMask[row] || [];
      for (let col = 0; col < cols; col += 1) {
        const flippedRow = rows - 1 - row;
        const idx = (flippedRow * cols + col) * 4;
        const value = line[col] ? 255 : 0;
        data[idx] = value;
        data[idx + 1] = value;
        data[idx + 2] = value;
        data[idx + 3] = 255;
      }
    }

    gl.texImage2D(
      gl.TEXTURE_2D,
      0,
      gl.RGBA,
      cols,
      rows,
      0,
      gl.RGBA,
      gl.UNSIGNED_BYTE,
      data
    );
  }

  setOverlayOptions(showOverlay, isSilhouette, overlayMode, overlayColor) {
    const { gl } = this;
    this.overlayEnabled = Boolean(showOverlay);
    this.isSilhouette = Boolean(isSilhouette);
    const modeValue =
      overlayMode === "color" ? 2 : overlayMode === "none" ? 0 : 1;
    const color = parseHexColor(overlayColor, [255, 255, 255]);
    let alpha = 1;
    if (typeof overlayColor === "string") {
      let trimmed = overlayColor.trim();
      if (trimmed.startsWith("#")) {
        trimmed = trimmed.slice(1);
      }
      if (trimmed.length === 8) {
        const parsedAlpha = parseInt(trimmed.slice(6, 8), 16);
        if (!Number.isNaN(parsedAlpha)) {
          alpha = parsedAlpha / 255;
        }
      }
    }
    gl.useProgram(this.program);
    gl.uniform1i(this.uniforms.showOverlay, this.overlayEnabled ? 1 : 0);
    gl.uniform1i(this.uniforms.isSilhouette, this.isSilhouette ? 1 : 0);
    if (this.uniforms.overlayMode != null) {
      gl.uniform1i(this.uniforms.overlayMode, modeValue);
    }
    if (this.uniforms.overlayColorOverride != null) {
      gl.uniform4f(
        this.uniforms.overlayColorOverride,
        color[0] / 255,
        color[1] / 255,
        color[2] / 255,
        alpha
      );
    }
  }

  setHover(hover) {
    const { gl } = this;
    gl.useProgram(this.program);
    if (Array.isArray(hover)) {
      const row = hover[0] | 0;
      const col = hover[1] | 0;
      this.currentHover = { row, col };
      gl.uniform1i(this.uniforms.hasHover, 1);
      gl.uniform2i(this.uniforms.hoverCell, col, row);
    } else {
      this.currentHover = null;
      gl.uniform1i(this.uniforms.hasHover, 0);
    }
    this.render();
  }

  render() {
    const { gl } = this;
    gl.useProgram(this.program);
    gl.clearColor(0, 0, 0, 0);
    gl.clear(gl.COLOR_BUFFER_BIT);
    gl.drawArrays(gl.TRIANGLES, 0, 6);
  }

  dispose() {
    const { gl } = this;
    if (this.boardTexture) {
      gl.deleteTexture(this.boardTexture);
      this.boardTexture = null;
    }
    if (this.brushTexture) {
      gl.deleteTexture(this.brushTexture);
      this.brushTexture = null;
    }
    if (this.tileTexture) {
      gl.deleteTexture(this.tileTexture);
      this.tileTexture = null;
    }
    if (this.program) {
      gl.deleteProgram(this.program);
    }
  }
}

export function create(canvas) {
  try {
    return new CanvasRenderer(canvas);
  } catch (error) {
    if (process.env.NODE_ENV !== "production") {
      console.warn(error);
    }
    return null;
  }
}

export function dispose(renderer) {
  if (renderer instanceof CanvasRenderer) {
    renderer.dispose();
  }
}

export function setSize(renderer, cols, rows, cellSize) {
  if (renderer instanceof CanvasRenderer) {
    renderer.setSize(cols, rows, cellSize);
  }
}

export function updateBoard(renderer, board, backgroundColor, isSilhouette) {
  if (renderer instanceof CanvasRenderer) {
    renderer.updateBoard(board, backgroundColor, isSilhouette);
  }
}

export function updateBrush(renderer, brush, centerRow, centerCol) {
  if (renderer instanceof CanvasRenderer) {
    renderer.updateBrush(brush, centerRow, centerCol);
  }
}

export function updateTileMask(renderer, tileMask) {
  if (renderer instanceof CanvasRenderer) {
    renderer.updateTileMask(tileMask);
  }
}

export function setOverlayOptions(
  renderer,
  showOverlay,
  isSilhouette,
  overlayMode,
  overlayColor
) {
  if (renderer instanceof CanvasRenderer) {
    renderer.setOverlayOptions(
      showOverlay,
      isSilhouette,
      overlayMode,
      overlayColor
    );
  }
}

export function setHover(renderer, hover) {
  if (renderer instanceof CanvasRenderer) {
    renderer.setHover(hover); // hover can be null or [row, col]
  }
}

export function render(renderer) {
  if (renderer instanceof CanvasRenderer) {
    renderer.render();
  }
}
