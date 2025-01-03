//
//  PixelShapeData.swift
//  Buzz
//
//  Created by Travis Baksh on 12/26/24.
//


import SwiftUI
import QRCode

enum PixelShapeData: String, CaseIterable, Codable {
  var id: String { rawValue }

  case abstract = "Abstract"
  case arrow = "Arrow"
  case blob = "Blob"
  case circle = "Circle"
  case circuit = "Circuit"
  case crt = "CRT"
  case curvePixel = "Curve Pixel"
  case donut = "Donut"
  case flower = "Flower"
  case grid2x2 = "Grid 2x2"
  case grid3x3 = "Grid 3x3"
  case grid4x4 = "Grid 4x4"
  case heart = "Heart"
  case horizontal = "Horizontal"
  case pointy = "Pointy"
  case razor = "Razor"
  case roundedEndIndent = "Rounded End Indent"
  case roundedPath = "Rounded Path"
  case roundedRect = "Rounded Rect"
  case sharp = "Sharp"
  case shiny = "Shiny"
  case spikyCircle = "Spiky Circle"
  case square = "Square"
  case squircle = "Squircle"
  case star = "Star"
  case stitch = "Stitch"
  case vertical = "Vertical"
  case vortex = "Vortex"
  case wave = "Wave"
  
  /// Generates the corresponding QRCode shape
  var generator: QRCodePixelShapeGenerator {
    switch self {
    case .abstract: QRCode.PixelShape.Abstract()
    case .arrow: QRCode.PixelShape.Arrow()
    case .blob: QRCode.PixelShape.Blob()
    case .circle: QRCode.PixelShape.Circle()
    case .circuit: QRCode.PixelShape.Circuit()
    case .crt: QRCode.PixelShape.CRT()
    case .curvePixel: QRCode.PixelShape.CurvePixel()
    case .donut: QRCode.PixelShape.Donut()
    case .flower: QRCode.PixelShape.Flower()
    case .grid2x2: QRCode.PixelShape.Grid2x2()
    case .grid3x3: QRCode.PixelShape.Grid3x3()
    case .grid4x4: QRCode.PixelShape.Grid4x4()
    case .heart: QRCode.PixelShape.Heart()
    case .horizontal: QRCode.PixelShape.Horizontal()
    case .pointy: QRCode.PixelShape.Pointy()
    case .razor: QRCode.PixelShape.Razor()
    case .roundedEndIndent: QRCode.PixelShape.RoundedEndIndent()
    case .roundedPath: QRCode.PixelShape.RoundedPath()
    case .roundedRect: QRCode.PixelShape.RoundedRect()
    case .sharp: QRCode.PixelShape.Sharp()
    case .shiny: QRCode.PixelShape.Shiny()
    case .spikyCircle: QRCode.PixelShape.SpikyCircle()
    case .square: QRCode.PixelShape.Square()
    case .squircle: QRCode.PixelShape.Squircle()
    case .star: QRCode.PixelShape.Star()
    case .stitch: QRCode.PixelShape.Stitch()
    case .vertical: QRCode.PixelShape.Vertical()
    case .vortex: QRCode.PixelShape.Vortex()
    case .wave: QRCode.PixelShape.Wave()
    }
  }
  

}


struct PixelShapeView: View {
  let shape: PixelShapeData
  
  var body: some View {
    VStack {
      shape
        .reference
        .resizable()
        .scaledToFit()
        .frame(width: 100, height: 100)
      
      Text(shape.rawValue)
        .font(.headline)
    }
  }
}

#Preview {
  ScrollView {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))]) {
      ForEach(PixelShapeData.allCases, id: \.self) { shape in
        PixelShapeView(shape: shape)
      }
    }
  }
}
