type triple = (float, float, float)
type texelType

@module("@texel/color") external okhsv: texelType = "OKHSV"
@module("@texel/color") external okhsl: texelType = "OKHSL"
@module("@texel/color") external oklch: texelType = "OKLCH"
@module("@texel/color") external srgb: texelType = "sRGB"

@module("@texel/color") external rgbToHex: triple => string = "RGBToHex"
@module("@texel/color") external hexToRgb: string => triple = "hexToRGB"

@module("@texel/color") external convert: (triple, texelType, texelType) => triple = "convert"
@module("@texel/color") external isRGBInGamut: triple => bool = "isRGBInGamut"
