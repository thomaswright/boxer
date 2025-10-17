@module("react-colorful") @react.component
external make: (
  ~color: string,
  ~onChange: string => unit,
  ~style: ReactDOMStyle.t=?,
  ~className: string=?,
) => React.element = "HexColorPicker"
