@module("./Switch.jsx") @react.component
external make: (~checked: bool, ~onChange: bool => unit) => React.element = "default"
