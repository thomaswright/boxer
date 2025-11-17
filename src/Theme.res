type theme =
  | @as("dark") Dark
  | @as("light") Light
  | @as("tan") Tan
  | @as("pink") Pink

let allThemes = ["light", "dark", "tan", "pink"]

@module("./useLocalStorage.js")
external useLocalStorage: (string, 'a) => ('a, ('a => 'a) => unit, unit => 'a) = "default"

@val @scope(("document", "documentElement", "classList"))
external addClassToHtmlElement: string => unit = "add"

@val @scope(("document", "documentElement", "classList"))
external removeClassToHtmlElement: string => unit = "remove"

let useTheme = () => {
  let (theme, setTheme, _getTheme) = useLocalStorage(StorageKeys.theme, Light)

  React.useEffect1(() => {
    allThemes->Array.forEach(t => removeClassToHtmlElement(t))
    addClassToHtmlElement((theme :> string))

    None
  }, [theme])

  (theme, setTheme)
}
