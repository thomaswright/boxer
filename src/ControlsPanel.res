@react.component
let make = (
  ~brushMode,
  ~setBrushMode,
  ~myColor,
  ~setMyColor,
  ~isPickingColor,
  ~onStartColorPick,
  ~canvasBackgroundColor,
  ~setCanvasBackgroundColor,
  ~viewportBackgroundColor,
  ~setViewportBackgroundColor,
  ~isSilhouette,
  ~setIsSilhouette,
  ~showCursorOverlay,
  ~setShowCursorOverlay,
  ~resizeMode,
  ~setResizeMode,
  ~resizeRowsInput,
  ~setResizeRowsInput,
  ~resizeColsInput,
  ~setResizeColsInput,
  ~canSubmitResize,
  ~onSubmitResize,
  ~zoom,
  ~onZoomIn,
  ~onZoomOut,
  ~onZoomReset,
  ~onCenterCanvas,
  ~onFitCanvas,
  ~exportScaleInput,
  ~setExportScaleInput,
  ~includeExportBackground,
  ~setIncludeExportBackground,
  ~canExport,
  ~onExport,
) => {
  <div className=" h-full overflow-x-visible flex flex-col w-48 py-2">
    <ColorControl
      brushMode
      setBrushMode
      myColor
      setMyColor
      isPickingColor
      onStartColorPick
    />
    <div className={"overflow-y-scroll flex-1 flex flex-col py-2 divide-y divide-gray-300"}>
      <CanvasColorsControl
        myColor
        canvasBackgroundColor
        setCanvasBackgroundColor
        viewportBackgroundColor
        setViewportBackgroundColor
      />
      <ZoomControl onZoomOut onZoomReset onZoomIn onCenterCanvas onFitCanvas zoom />
      <SilhouetteControl isSilhouette setIsSilhouette />
      <ExportControl
        exportScaleInput
        setExportScaleInput
        includeBackground={includeExportBackground}
        setIncludeBackground={setIncludeExportBackground}
        canExport
        onExport
      />
      <CanvasSizeControl
        resizeRowsInput
        setResizeRowsInput
        resizeColsInput
        setResizeColsInput
        resizeMode
        setResizeMode
        canSubmitResize
        onSubmitResize
      />
      <BrushOverlayControl showCursorOverlay setShowCursorOverlay />
    </div>
  </div>
}
