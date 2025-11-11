type theme =
  | @as("dark") Dark
  | @as("light") Light

@module("./useLocalStorage.js")
external useLocalStorage: (string, 'a) => ('a, ('a => 'a) => unit, unit => 'a) = "default"

@val @scope(("document", "documentElement", "classList"))
external addClassToHtmlElement: string => unit = "add"

@val @scope(("document", "documentElement", "classList"))
external removeClassToHtmlElement: string => unit = "remove"

let useTheme = () => {
  let (theme, setTheme, _getTheme) = useLocalStorage(StorageKeys.theme, Light)

  React.useEffect1(() => {
    let (remove, add) = theme == Dark ? ("light", "dark") : ("dark", "light")

    removeClassToHtmlElement(remove)
    addClassToHtmlElement(add)

    None
  }, [theme])

  (theme, setTheme)
}
