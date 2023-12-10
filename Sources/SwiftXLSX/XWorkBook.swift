// Copyright 2022
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
//  Created by Kostiantyn Bohonos on 1/19/22.
//

import Foundation
import Collections
#if os(macOS)
import Cocoa
#else
import UIKit
#endif
import ZIPFoundation



final public class XWorkBook{
    private var Sheets:[XSheet] = []
    
    // for styles
    private var Fonts:[UInt64:(String,Int)] = [:]
    private var Fills:[String] = []
    private var colorsid:OrderedSet<String> = []
    private var Bgcolor:[String] = []
    private var xfs:[UInt64:(String,Int)] = [:]
    private var Borders:[String] = []
    private var Drawings:[String] = []
    private var NumberFormats:[UInt64:(String,Int)] = [:]
    
    private var vals:[String] = []
    private var valss:Set<String> = Set([])
    private var CHARSIZE:[UInt64:CGFloat] = [:]
    
    public init() {}
    
    var count:Int {
        return self.Sheets.count
    }
    
    func removeAll(){
        self.Sheets.removeAll()
    }
    
    func append(_ newElement: XSheet){
        self.Sheets.append(newElement)
    }
    
    /// create and return new sheet
    public func NewSheet(_ title:String) -> XSheet{
        let Sheet = XSheet(title.XSheetTitle())
        self.append(Sheet)
        return Sheet
    }
    /// clear all local data for building xlsx
    private func clearlocaldata(){
        self.Fonts.removeAll()
        self.colorsid.removeAll()
        self.Fills.removeAll()
        self.Borders.removeAll()
        self.xfs.removeAll()
        self.vals.removeAll()
        self.vals.append("")
        self.valss.removeAll()
        self.valss.insert("")
        self.CHARSIZE.removeAll()
        self.Bgcolor.removeAll()
        self.NumberFormats.removeAll()
    }
    
    private func findFont(_ cell:XCell){
        let font = cell.Font!
        
        var idval:UInt64 = cell.Font!.bold ? 1 : 0
        idval += cell.Font!.italic ? 2 : 0
        idval += cell.Font!.strike ? 3 : 0
        idval += cell.Font!.underline ? 15 : 0
        idval += UInt64(cell.Font!.FontSize) * 10
        idval += (UInt64(cell.Font!.Font.ind())+1) * 10000
        
        
        let col:ColorClass = cell.color
        if let hex = col.Hex {
            if let index = self.colorsid.firstIndex(of: hex) {
                idval += (UInt64(index)+1) * 1000000
            }else{
                self.colorsid.append(hex)
                idval += UInt64(self.colorsid.count) * 1000000
            }
        }
        
        if let (_,ind) = self.Fonts[idval] {
            cell.idFont = ind
        }else{
            let xml = "<font>\(font.bold ? "<b/>" : "")\(font.italic ? "<i/>" : "")\(font.strike ? "<strike/>" : "")\(font.underline ? "<u/>" : "")<sz val=\"\(font.FontSize)\"/><color rgb=\"\(cell.color.Hex!)\"/><name val=\"\(font.Font)\"/></font>"
            
            cell.idFont = self.Fonts.count
            self.Fonts[idval] = (xml,self.Fonts.count)
        }
    }
    
    private func findNumberFormats(_ cell:XCell){
        let numberFormat = cell.numFormat
        
        var idval:UInt64 = numberFormat.ind()
        
        if idval == UInt64.max {
            
            if let (_,ind) = self.NumberFormats[idval] {
                cell.idNumFormat = ind
            }else{
                var format = ""
                
                switch numberFormat {
                case .custom(let f):
                    format = f
                    break
                case .date(let f):
                    format = f
                    break
                case .time(let f):
                    format = f
                    break
                default:
                    format = ""
                }
                
                var id = (self.NumberFormats.count + 50)
                
                let xml = "<numFmt numFmtId=\"\(id)\" formatCode=\"\(format)\"/>"
                
                cell.idNumFormat = id
                self.NumberFormats[idval] = (xml,id)
            }
        } else {
            cell.idNumFormat = Int(idval)
        }
    }
    
    private func findFills(_ cell:XCell){
        let hexcolor = cell.colorbackground.Hex!
        
        if let index = self.Bgcolor.firstIndex(of: hexcolor) {
            cell.idFill = index
        }else{
            self.Bgcolor.append(hexcolor)
            let Fontxml = "<fill><patternFill patternType=\"solid\"><fgColor rgb=\"\(hexcolor)\"/><bgColor indexed=\"64\"/></patternFill></fill>"
            
            if let indexfill = self.Fills.firstIndex(of: Fontxml) {
                cell.idFill = indexfill
            }else{
                self.Fills.append(Fontxml)
                cell.idFill = self.Fills.count-1
            }
        }
    }
    
    private func findxf(_ cell:XCell,_ sheet:XSheet){
        cell.idStyle = -1
        var idval: UInt64 = cell.alignmentHorizontal.id()
        idval += cell.alignmentVertical.id() * 10
        idval += cell.Border ? 100 : 0
        idval += UInt64(cell.idFill) * 1000
        idval += UInt64(cell.idFont) * 1000000
        
        for merge in sheet.merge {
            if merge.inrect(cell.coords!){
                if let cellmain = sheet.Get(XCoords(row: merge.row, col: merge.col)) {
                    cell.idStyle = cellmain.idStyle
                    cell.idFont = cellmain.idFont
                    cell.idFill = cellmain.idFill
                    break
                }
            }
        }
        if cell.idStyle == -1 {
            if let (_,ind) = self.xfs[idval] {
                cell.idStyle = ind
            }else{
                let xf = "<xf fontId=\"\(cell.idFont)\" numFmtId=\"\(cell.idNumFormat)\" fillId=\"\(cell.idFill)\" borderId=\"\(cell.Border ? "1" : "0")\" applyFont=\"1\" applyNumberFormat=\"\(cell.idNumFormat)\" applyFill=\"1\" applyBorder=\"1\" applyAlignment=\"1\"><alignment horizontal=\"\(cell.alignmentHorizontal.str())\" vertical=\"\(cell.alignmentVertical.str())\" textRotation=\"0\" wrapText=\"true\" shrinkToFit=\"false\"/></xf>"
                cell.idStyle = self.xfs.count
                self.xfs[idval] = (xf,self.xfs.count)
            }
        }
    }
    
    private func findVals(_ cell:XCell){
        cell.idVal = nil
        if let val = cell.value {
            switch val {
            case .text(let strval):
                let key:UInt64 =  cell.Font!.Font.ind()*1000000+UInt64(cell.Font!.FontSize)
                var sf:CGFloat = 0
                if let sizefont = self.CHARSIZE[key] {
                    sf = sizefont
                }else{
                    let size = cell.Font!.getfont!.Rectfor("0")
                    self.CHARSIZE[key] = size.width
                    sf = size.width
                }
                cell.width = Int(sf * CGFloat(strval.count) + 10)
                
                if self.valss.contains(strval) {
                    if let indexval = self.vals.firstIndex(of: strval) {
                        cell.idVal = indexval
                    }
                }else{
                    self.vals.append(strval)
                    self.valss.insert(strval)
                    cell.idVal = self.vals.count - 1
                }
            default:
                break
            }
        }
    }
    
    private func BuildMediaDrawings(){
        self.Drawings.removeAll()
        var indexsheet = 0
        for sheet in self {
            indexsheet += 1
            sheet.drawingsxml = nil
            sheet.drawingsxmlrels = nil
            sheet.drawingsSheetrels = nil
            
            var cellwithicon:[(xic:XImageCell,Coords:XCoords)] = []
            var keys:[String] = []
            
            
            for cell in sheet {
                
                guard let cellvalue = cell.value else {continue}
                switch cellvalue {
                case .icon(let XIC):
                    if keys.firstIndex(of: XIC.key) == nil {
                        keys.append(XIC.key)
                    }
                    cellwithicon.append((xic:XIC,Coords:cell.coords!))
                default:
                    continue
                }
            }
            
            if cellwithicon.count > 0 {
                /// we have some cell with images
                
                let Xml:NSMutableString = NSMutableString()
                let Xmlrel:NSMutableString = NSMutableString()
                Xml.append("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>")
                Xml.append("<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">")
                var index = 1
                for key in keys {
                    Xml.append("<Relationship Id=\"rId\(index)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"../media/\(key).png\"/>")
                    index += 1
                }
                if keys.count > 0 {
                    Xmlrel.append("<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/drawing\" Target=\"../drawings/drawing\(indexsheet).xml\"/>")
                }
                
                Xml.append("</Relationships>")
                sheet.drawingsxmlrels = String(Xml)
                sheet.drawingsSheetrels = String(Xmlrel)
                Xml.setString("")
                Xmlrel.setString("")
                
                
                
                
                Xml.append("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>")
                let str = """
<xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart" xmlns:cx="http://schemas.microsoft.com/office/drawing/2014/chartex" xmlns:cx1="http://schemas.microsoft.com/office/drawing/2015/9/8/chartex" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:dgm="http://schemas.openxmlformats.org/drawingml/2006/diagram" xmlns:x3Unk="http://schemas.microsoft.com/office/drawing/2010/slicer" xmlns:sle15="http://schemas.microsoft.com/office/drawing/2012/slicer">
"""
                Xml.append(str)
                for cell in cellwithicon {
                    let index = keys.firstIndex(of: cell.xic.key)!
                    
                    let EMU = 9525.0
                    
                    let y:UInt32 = UInt32(cell.xic.size.height*EMU)
                    let x:UInt32 = UInt32(cell.xic.size.width*EMU)
                    
                    
                    
                    let cellstr = """
<xdr:oneCellAnchor><xdr:from><xdr:col>\(cell.Coords.col-1)</xdr:col><xdr:colOff>0</xdr:colOff><xdr:row>\(cell.Coords.row-1)</xdr:row><xdr:rowOff>0</xdr:rowOff></xdr:from><xdr:ext cx="\(x)" cy="\(y)"/><xdr:pic><xdr:nvPicPr><xdr:cNvPr id="0" name="\(cell.xic.key).png"/><xdr:cNvPicPr preferRelativeResize="0"/></xdr:nvPicPr><xdr:blipFill><a:blip cstate="print" r:embed="rId\(index+1)"/><a:stretch><a:fillRect/></a:stretch></xdr:blipFill><xdr:spPr><a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:noFill/></xdr:spPr></xdr:pic><xdr:clientData fLocksWithSheet="0"/></xdr:oneCellAnchor>
"""
                    Xml.append(cellstr)
                }
                Xml.append("</xdr:wsDr>")
                sheet.drawingsxml = String(Xml)
                Xml.setString("")
            }
        }
    }
    
    private func BuildStyles(){
        self.clearlocaldata()
        
        self.Fonts[0] = ("<font><sz val=\"10\"/><color rgb=\"FF000000\"/><name val=\"Arial\"/></font>",0)
        
        self.Fills.append("<fill><patternFill patternType=\"solid\"><fgColor rgb=\"FFFFFFFF\"/><bgColor indexed=\"64\"/></patternFill></fill>")
        
        self.Bgcolor.append("FFFFFFFF")
        
        self.xfs[0] = ("<xf fontId=\"0\" numFmtId=\"0\" fillId=\"0\" borderId=\"0\" applyFont=\"1\" applyNumberFormat=\"0\" applyFill=\"1\" applyBorder=\"1\" applyAlignment=\"1\"><alignment horizontal=\"center\" vertical=\"center\" textRotation=\"0\" wrapText=\"true\" shrinkToFit=\"false\"/></xf>",0)
        
        self.Borders.append("<border/>");
        self.Borders.append("<border><left style=\"thin\"><color rgb=\"FF000000\"/></left><right style=\"thin\"><color rgb=\"FF000000\"/></right><top style=\"thin\"><color rgb=\"FF000000\"/></top><bottom style=\"thin\"><color rgb=\"FF000000\"/></bottom></border>");
        
        
        for sheet in self {
            for cell in sheet {
                self.findFont(cell)
                self.findFills(cell)
                self.findNumberFormats(cell)
                self.findxf(cell , sheet)
                self.findVals(cell)
            }
        }
    }
    
    private func BuildSheet(_ sheet:XSheet){
        sheet.buildindex()
        let Xml:NSMutableString = NSMutableString()
        Xml.append("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n")
        Xml.append("<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\" xmlns:mx=\"http://schemas.microsoft.com/office/mac/excel/2008/main\" xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\" xmlns:mv=\"urn:schemas-microsoft-com:mac:vml\" xmlns:x14=\"http://schemas.microsoft.com/office/spreadsheetml/2009/9/main\" xmlns:x15=\"http://schemas.microsoft.com/office/spreadsheetml/2010/11/main\"  xmlns:x14ac=\"http://schemas.microsoft.com/office/spreadsheetml/2009/9/ac\" xmlns:xm=\"http://schemas.microsoft.com/office/excel/2006/main\">")
        
        let (numrows,numcols) = sheet.GetMaxRowCol
        
        if numrows>0 {
            Xml.append("<dimension ref=\"A1:\(XSheet.EncodeNumberABC(numcols-1))\(numrows)\"/>")
        }
        
        Xml.append("<sheetViews>")
        if (sheet.fix.row + sheet.fix.col) == 0 {
            Xml.append("<sheetView workbookViewId=\"0\" />")
        }else if sheet.fix.row > 0 , sheet.fix.col == 0 {
            Xml.append("<sheetView workbookViewId=\"0\">")
            Xml.append("<pane ySplit=\"\(sheet.fix.row)\" topLeftCell=\"A\(sheet.fix.row+1)\" activePane=\"bottomLeft\" state=\"frozen\"/>")
            Xml.append("</sheetView>")
        }else if sheet.fix.row == 0 , sheet.fix.col > 0 {
            Xml.append("<sheetView workbookViewId=\"0\">")
            Xml.append("<pane xSplit=\"\(sheet.fix.col)\" topLeftCell=\"\(XSheet.EncodeNumberABC(sheet.fix.col))1\" activePane=\"topRight\" state=\"frozen\"/>")
            Xml.append("</sheetView>")
        }else{
            Xml.append("<sheetView workbookViewId=\"0\">")
            Xml.append("<pane xSplit=\"\(sheet.fix.col)\" ySplit=\"\(sheet.fix.row)\" topLeftCell=\"\(XSheet.EncodeNumberABC(sheet.fix.col))\(sheet.fix.row+1)\" activePane=\"bottomRight\" state=\"frozen\"/>")
            Xml.append("</sheetView>")
        }
        Xml.append("</sheetViews>")
        Xml.append("<sheetFormatPr  customHeight=\"1\" defaultColWidth=\"12.63\" defaultRowHeight=\"15.75\" outlineLevelRow=\"0\" outlineLevelCol=\"0\"/>")
        
        if numcols>0 {
            Xml.append("<cols>")
            for col:Int in 1...numcols {
                var wcalc:CGFloat = 50
                if sheet.ColW.count > 0 {
                    let w = sheet.ColW[col]
                    if w != nil {
                        wcalc = CGFloat(w!)
                    }else{
                        wcalc  = CGFloat(sheet.GetMaxWidth(col, numrows))
                    }
                }else{
                    wcalc  = CGFloat(sheet.GetMaxWidth(col, numrows))
                }
                wcalc = wcalc * (0.16666016 * 1.2)//0.12499512
                
                Xml.append("<col min=\"\(col)\" max=\"\(col == numcols ? 16384 : col)\" width=\"\(wcalc)\" customWidth=\"1\" style=\"0\"/>")
            }
            Xml.append("</cols>")
        }
        
        
        
        Xml.append("<sheetData>")
        var hasimages = false
        if numrows == 0 {
            Xml.append("<row r=\"1\" spans=\"1:1\"><c r=\"A1\"/></row>")
        }else{
            for row:Int in 1...numrows {
                let colls:NSMutableString = NSMutableString()
                for col:Int in 1...numcols {
                    if let cell = sheet.Get(XCoords(row: row, col: col)) {
                        /// output  values
                        if let value = cell.value {
                            switch value {
                            case .text(_):
                                if cell.idVal != nil {
                                    /// this is text value and insert like id
                                    colls.append("<c r=\"\(XSheet.EncodeNumberABC(col-1))\(row)\" s=\"\(cell.idStyle)\" t=\"s\"><v>\(cell.idVal!)</v></c>")
                                }else{
                                    /// output empty cell
                                    colls.append("<c r=\"\(XSheet.EncodeNumberABC(col-1))\(row)\" s=\"\(cell.idStyle >= 0 ? cell.idStyle : 0)\" />")
                                }
                            case .double(let val):
                                colls.append("<c r=\"\(XSheet.EncodeNumberABC(col-1))\(row)\" s=\"\(cell.idStyle)\" ><v>\(String(format: "%.3f", val))</v></c>")
                            case .float(let val):
                                colls.append("<c r=\"\(XSheet.EncodeNumberABC(col-1))\(row)\" s=\"\(cell.idStyle)\" ><v>\(String(format: "%.3f", val))</v></c>")
                            case.integer(let val):
                                colls.append("<c r=\"\(XSheet.EncodeNumberABC(col-1))\(row)\" s=\"\(cell.idStyle)\" ><v>\(val)</v></c>")
                            case .long(let val):
                                colls.append("<c r=\"\(XSheet.EncodeNumberABC(col-1))\(row)\" s=\"\(cell.idStyle)\" ><v>\(val)</v></c>")
                            case .icon(_):
                                /// output empty cell
                                hasimages = true
                                colls.append("<c r=\"\(XSheet.EncodeNumberABC(col-1))\(row)\" s=\"\(cell.idStyle >= 0 ? cell.idStyle : 0)\" />")
                            case .formula(let formula, let preVal):
                                colls.append("<c r=\"\(XSheet.EncodeNumberABC(col-1))\(row)\" s=\"\(cell.idStyle)\" ><f>\(formula)</f><v>\(preVal)</v></c>")
                            }
                        }else{
                            colls.append("<c r=\"\(XSheet.EncodeNumberABC(col-1))\(row)\" s=\"\(cell.idStyle >= 0 ? cell.idStyle : 0)\" />")
                        }
                        
                    }else{
                        /// no cell with coords (row,col)
                        colls.append("<c r=\"\(XSheet.EncodeNumberABC(col-1))\(row)\" s=\"0\" />")
                    }
                }
                if let ht = sheet.RowH[row] {
                    Xml.append("<row r=\"\(row)\" spans=\"1:\(numcols)\" ht=\"\(ht)\" customHeight=\"1\">")
                }else{
                    Xml.append("<row r=\"\(row)\" spans=\"1:\(numcols)\">")
                }
                Xml.append(String(colls))
                colls.setString("")
                Xml.append("</row>")
            }
        }
        Xml.append("</sheetData>")
        if hasimages {
            Xml.append("<drawing r:id=\"rId1\"/>")
        }
        
        
        
        if sheet.mergecells.count > 0 {
            Xml.append("<mergeCells count=\"\(sheet.mergecells.count)\">")
            for addr in sheet.mergecells {
                Xml.append("<mergeCell ref=\"\(addr)\"/>")
            }
            Xml.append("</mergeCells>")
        }
        
        Xml.append("</worksheet>")
        sheet.xml = String(Xml)
        Xml.setString("")
    }
    
    private func BuildSheets() {
        for sheet in self {
            self.BuildSheet(sheet)
        }
    }
    
    
    
    
    
    /// Check exist directory and create if don't exist
    @discardableResult
    private func CheckCreateDirectory(path pathdirectory:String) -> Bool{
        let filemanager = FileManager.default
        if !filemanager.fileExists(atPath: pathdirectory) {
            do {
                try filemanager.createDirectory(atPath: pathdirectory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Error creating directory \(pathdirectory) : \(error.localizedDescription)")
                return false
            }
        }
        return true
    }
    
    /// remove file or directory
    @discardableResult
    private func RemoveFile(path pathfile:String) -> Bool{
        do {
            try FileManager.default.removeItem(atPath: pathfile)
        } catch {
            print("Error remove file \(pathfile) : \(error.localizedDescription)")
            return false
        }
        return true
    }
    
    /// write string buffer to file
    @discardableResult
    private func Write(data strData:String, tofile path:String) -> Bool{
        do {
            try strData.write(toFile: path, atomically: true, encoding: .utf8)
        } catch {
            print("Error write file \(path) : \(error.localizedDescription)")
            return false
        }
        return true
    }
    
    private var rels:String {
        "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"xl/workbook.xml\"/></Relationships>"
    }
    
    private var SharedStrings:String {
        let Xml:NSMutableString = NSMutableString()
        Xml.append("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n")
        Xml.append("<sst xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" uniqueCount=\"\(self.vals.count)\">")
        for val in vals {
            Xml.append("<si><t>\(val.XmlPrep())</t></si>")
        }
        Xml.append("</sst>")
        return String(Xml)
    }
    
    private var StyleStrings:String {
        let Xml:NSMutableString = NSMutableString()
        
        Xml.append("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n")
        Xml.append("<styleSheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\" mc:Ignorable=\"x14ac\" xmlns:x14ac=\"http://schemas.microsoft.com/office/spreadsheetml/2009/9/ac\">")
//        Xml.append("<numFmts count=\"0\"/>")
        
        
        if !NumberFormats.isEmpty {
            Xml.append("<numFmts count=\"\(NumberFormats.count)\">")
            let ar = NumberFormats.values.sorted(by: {  $0.1 < $1.1})
            
            for (nf,_) in ar {
                Xml.append(nf)
            }
            
            Xml.append("</numFmts>")
        }
        
        if Fonts.isEmpty {
            Xml.append("<fonts count=\"0\"/>")
        }else{
            Xml.append("<fonts count=\"\(Fonts.count)\" x14ac:knownFonts=\"1\" >")
            let ar = Fonts.values.sorted(by: {  $0.1 < $1.1})
            
            for (font,_) in ar {
                Xml.append(font)
            }
            
            Xml.append("</fonts>")
        }
        
        if Fills.isEmpty {
            Xml.append("<fills count=\"0\"/>")
        }else{
            Xml.append("<fills count=\"\(Fills.count)\">")
            for fill in Fills {
                Xml.append(fill)
            }
            Xml.append("</fills>")
        }
        
        if Borders.isEmpty {
            Xml.append("<borders count=\"0\"/>")
        }else{
            Xml.append("<borders count=\"\(Borders.count)\">")
            for border in Borders {
                Xml.append(border)
            }
            Xml.append("</borders>")
        }
        
        Xml.append("<cellStyleXfs count=\"1\">")
        Xml.append("<xf numFmtId=\"0\" fontId=\"0\" fillId=\"0\" borderId=\"0\"/>")
        Xml.append("</cellStyleXfs>")
        
        if xfs.isEmpty {
            Xml.append("<cellXfs count=\"0\"/>")
        }else{
            Xml.append("<cellXfs count=\"\(xfs.count)\">")
            
            let ar = xfs.values.sorted(by: {  $0.1 < $1.1})
            for (xf,_) in ar {
                Xml.append(xf)
            }
            Xml.append("</cellXfs>")
        }
        
        Xml.append("<cellStyles count=\"1\"><cellStyle name=\"Normal\" xfId=\"0\" builtinId=\"0\"/></cellStyles>")
        Xml.append("<dxfs count=\"0\"/>")
        Xml.append("<tableStyles count=\"0\" defaultTableStyle=\"TableStyleMedium2\" defaultPivotStyle=\"PivotStyleLight16\"/>")
        Xml.append("<extLst><ext uri=\"{EB79DEF2-80B8-43e5-95BD-54CBDDF9020C}\" xmlns:x14=\"http://schemas.microsoft.com/office/spreadsheetml/2009/9/main\"><x14:slicerStyles defaultSlicerStyle=\"SlicerStyleLight1\"/></ext></extLst>")
        Xml.append("</styleSheet>")
        
        return String(Xml)
    }
    
    private var ContentTypesStrings:String {
        let Xml:NSMutableString = NSMutableString()
        Xml.append("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n")
        Xml.append("<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">")
        Xml.append("<Default ContentType=\"application/xml\" Extension=\"xml\"/>")
        Xml.append("<Default ContentType=\"image/png\" Extension=\"png\"/>")
        
        Xml.append("<Default ContentType=\"application/vnd.openxmlformats-package.relationships+xml\" Extension=\"rels\"/>")
        for i in 1...Sheets.count {
            Xml.append("<Override ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\" PartName=\"/xl/worksheets/sheet\(i).xml\"/>")
        }
        
        Xml.append("<Override ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml\" PartName=\"/xl/sharedStrings.xml\"/>")
        for i in 1...Sheets.count {
            if Sheets[i-1].drawingsSheetrels != nil {
                Xml.append("<Override ContentType=\"application/vnd.openxmlformats-officedocument.drawing+xml\" PartName=\"/xl/drawings/drawing\(i).xml\"/>")
            }
        }
        
        
        Xml.append("<Override ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml\" PartName=\"/xl/styles.xml\"/>")
        Xml.append("<Override ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\" PartName=\"/xl/workbook.xml\"/>")
        Xml.append("</Types>")
        return String(Xml)
    }
    
    private var WorkBookXmlRelsStrings:String {
        let Xml:NSMutableString = NSMutableString()
        let str = """
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>
<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="theme/theme1.xml"/>
"""
        Xml.append(str)
        for i in 1...Sheets.count {
            Xml.append("<Relationship Id=\"rId\(i+3)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet\(i).xml\"/>")
        }
        Xml.append("</Relationships>")
        return String(Xml)
    }
    
    private var WorkBookXmlStrings:String {
        let Xml:NSMutableString = NSMutableString()
        
        Xml.append("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n")
        Xml.append("<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\" xmlns:mx=\"http://schemas.microsoft.com/office/mac/excel/2008/main\" xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\" xmlns:mv=\"urn:schemas-microsoft-com:mac:vml\" xmlns:x14=\"http://schemas.microsoft.com/office/spreadsheetml/2009/9/main\" xmlns:x15=\"http://schemas.microsoft.com/office/spreadsheetml/2010/11/main\" xmlns:x14ac=\"http://schemas.microsoft.com/office/spreadsheetml/2009/9/ac\" xmlns:xm=\"http://schemas.microsoft.com/office/excel/2006/main\">")
        Xml.append("<workbookPr defaultThemeVersion=\"124226\" />")
        Xml.append("<sheets>")
        for i in 1...Sheets.count {
            Xml.append("<sheet state=\"visible\" name=\"\(Sheets[i-1].title)\" sheetId=\"\(i)\" r:id=\"rId\(i+3)\"/>")
        }
        
        
        
        Xml.append("</sheets>")
        Xml.append("<definedNames/>")
        Xml.append("<calcPr/>")
        Xml.append("</workbook>")
        return String(Xml)
    }
    
    private var HeadSheedXML: String {
        "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">"
    }
    private var HeadSheedXMLEnd: String {
        "</Relationships>"
    }
    
    /// prepare files for Xlsx file
    private func preparefiles(for filename:String) -> String{
        var CachePath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0]
        
        CachePath = "\(CachePath)/tmpxls"
        self.CheckCreateDirectory(path: CachePath)
        
        let FolderId = "folderxls\(arc4random())"
        let BasePath = "\(CachePath)/\(FolderId)"
        self.CheckCreateDirectory(path: BasePath)
        self.CheckCreateDirectory(path: "\(BasePath)/_rels")
        self.CheckCreateDirectory(path: "\(BasePath)/xl")
        self.CheckCreateDirectory(path: "\(BasePath)/xl/media")
        
        
        for (_,ximg) in XImages.list {
            ximg.Write(toPath: "\(BasePath)/xl/media/")
        }
        
        
        
        self.CheckCreateDirectory(path: "\(BasePath)/xl/_rels")
        self.CheckCreateDirectory(path: "\(BasePath)/xl/worksheets")
        self.CheckCreateDirectory(path: "\(BasePath)/xl/worksheets/_rels")
        self.CheckCreateDirectory(path: "\(BasePath)/xl/drawings")
        self.CheckCreateDirectory(path: "\(BasePath)/xl/drawings/_rels")
        
        self.CheckCreateDirectory(path: "\(BasePath)/xl/theme")
        
        let style = """
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Office Theme">
    <a:themeElements>
        <a:clrScheme name="Office">
            <a:dk1>
                <a:sysClr val="windowText" lastClr="000000"/>
            </a:dk1>
            <a:lt1>
                <a:sysClr val="window" lastClr="FFFFFF"/>
            </a:lt1>
            <a:dk2>
                <a:srgbClr val="1F497D"/>
            </a:dk2>
            <a:lt2>
                <a:srgbClr val="EEECE1"/>
            </a:lt2>
            <a:accent1>
                <a:srgbClr val="4F81BD"/>
            </a:accent1>
            <a:accent2>
                <a:srgbClr val="C0504D"/>
            </a:accent2>
            <a:accent3>
                <a:srgbClr val="9BBB59"/>
            </a:accent3>
            <a:accent4>
                <a:srgbClr val="8064A2"/>
            </a:accent4>
            <a:accent5>
                <a:srgbClr val="4BACC6"/>
            </a:accent5>
            <a:accent6>
                <a:srgbClr val="F79646"/>
            </a:accent6>
            <a:hlink>
                <a:srgbClr val="0000FF"/>
            </a:hlink>
            <a:folHlink>
                <a:srgbClr val="800080"/>
            </a:folHlink>
        </a:clrScheme>
        <a:fontScheme name="Office">
            <a:majorFont>
                <a:latin typeface="Cambria"/>
                <a:ea typeface=""/>
                <a:cs typeface=""/>
                <a:font script="Jpan" typeface="ＭＳ Ｐゴシック"/>
                <a:font script="Hang" typeface="맑은 고딕"/>
                <a:font script="Hans" typeface="宋体"/>
                <a:font script="Hant" typeface="新細明體"/>
                <a:font script="Arab" typeface="Times New Roman"/>
                <a:font script="Hebr" typeface="Times New Roman"/>
                <a:font script="Thai" typeface="Tahoma"/>
                <a:font script="Ethi" typeface="Nyala"/>
                <a:font script="Beng" typeface="Vrinda"/>
                <a:font script="Gujr" typeface="Shruti"/>
                <a:font script="Khmr" typeface="MoolBoran"/>
                <a:font script="Knda" typeface="Tunga"/>
                <a:font script="Guru" typeface="Raavi"/>
                <a:font script="Cans" typeface="Euphemia"/>
                <a:font script="Cher" typeface="Plantagenet Cherokee"/>
                <a:font script="Yiii" typeface="Microsoft Yi Baiti"/>
                <a:font script="Tibt" typeface="Microsoft Himalaya"/>
                <a:font script="Thaa" typeface="MV Boli"/>
                <a:font script="Deva" typeface="Mangal"/>
                <a:font script="Telu" typeface="Gautami"/>
                <a:font script="Taml" typeface="Latha"/>
                <a:font script="Syrc" typeface="Estrangelo Edessa"/>
                <a:font script="Orya" typeface="Kalinga"/>
                <a:font script="Mlym" typeface="Kartika"/>
                <a:font script="Laoo" typeface="DokChampa"/>
                <a:font script="Sinh" typeface="Iskoola Pota"/>
                <a:font script="Mong" typeface="Mongolian Baiti"/>
                <a:font script="Viet" typeface="Times New Roman"/>
                <a:font script="Uigh" typeface="Microsoft Uighur"/>
                <a:font script="Geor" typeface="Sylfaen"/>
            </a:majorFont>
            <a:minorFont>
                <a:latin typeface="Calibri"/>
                <a:ea typeface=""/>
                <a:cs typeface=""/>
                <a:font script="Jpan" typeface="ＭＳ Ｐゴシック"/>
                <a:font script="Hang" typeface="맑은 고딕"/>
                <a:font script="Hans" typeface="宋体"/>
                <a:font script="Hant" typeface="新細明體"/>
                <a:font script="Arab" typeface="Arial"/>
                <a:font script="Hebr" typeface="Arial"/>
                <a:font script="Thai" typeface="Tahoma"/>
                <a:font script="Ethi" typeface="Nyala"/>
                <a:font script="Beng" typeface="Vrinda"/>
                <a:font script="Gujr" typeface="Shruti"/>
                <a:font script="Khmr" typeface="DaunPenh"/>
                <a:font script="Knda" typeface="Tunga"/>
                <a:font script="Guru" typeface="Raavi"/>
                <a:font script="Cans" typeface="Euphemia"/>
                <a:font script="Cher" typeface="Plantagenet Cherokee"/>
                <a:font script="Yiii" typeface="Microsoft Yi Baiti"/>
                <a:font script="Tibt" typeface="Microsoft Himalaya"/>
                <a:font script="Thaa" typeface="MV Boli"/>
                <a:font script="Deva" typeface="Mangal"/>
                <a:font script="Telu" typeface="Gautami"/>
                <a:font script="Taml" typeface="Latha"/>
                <a:font script="Syrc" typeface="Estrangelo Edessa"/>
                <a:font script="Orya" typeface="Kalinga"/>
                <a:font script="Mlym" typeface="Kartika"/>
                <a:font script="Laoo" typeface="DokChampa"/>
                <a:font script="Sinh" typeface="Iskoola Pota"/>
                <a:font script="Mong" typeface="Mongolian Baiti"/>
                <a:font script="Viet" typeface="Arial"/>
                <a:font script="Uigh" typeface="Microsoft Uighur"/>
                <a:font script="Geor" typeface="Sylfaen"/>
            </a:minorFont>
        </a:fontScheme>
        <a:fmtScheme name="Office">
            <a:fillStyleLst>
                <a:solidFill>
                    <a:schemeClr val="phClr"/>
                </a:solidFill>
                <a:gradFill rotWithShape="1">
                    <a:gsLst>
                        <a:gs pos="0">
                            <a:schemeClr val="phClr">
                                <a:tint val="50000"/>
                                <a:satMod val="300000"/>
                            </a:schemeClr>
                        </a:gs>
                        <a:gs pos="35000">
                            <a:schemeClr val="phClr">
                                <a:tint val="37000"/>
                                <a:satMod val="300000"/>
                            </a:schemeClr>
                        </a:gs>
                        <a:gs pos="100000">
                            <a:schemeClr val="phClr">
                                <a:tint val="15000"/>
                                <a:satMod val="350000"/>
                            </a:schemeClr>
                        </a:gs>
                    </a:gsLst>
                    <a:lin ang="16200000" scaled="1"/>
                </a:gradFill>
                <a:gradFill rotWithShape="1">
                    <a:gsLst>
                        <a:gs pos="0">
                            <a:schemeClr val="phClr">
                                <a:tint val="100000"/>
                                <a:shade val="100000"/>
                                <a:satMod val="130000"/>
                            </a:schemeClr>
                        </a:gs>
                        <a:gs pos="100000">
                            <a:schemeClr val="phClr">
                                <a:tint val="50000"/>
                                <a:shade val="100000"/>
                                <a:satMod val="350000"/>
                            </a:schemeClr>
                        </a:gs>
                    </a:gsLst>
                    <a:lin ang="16200000" scaled="0"/>
                </a:gradFill>
            </a:fillStyleLst>
            <a:lnStyleLst>
                <a:ln w="9525" cap="flat" cmpd="sng" algn="ctr">
                    <a:solidFill>
                        <a:schemeClr val="phClr">
                            <a:shade val="95000"/>
                            <a:satMod val="105000"/>
                        </a:schemeClr>
                    </a:solidFill>
                    <a:prstDash val="solid"/>
                </a:ln>
                <a:ln w="25400" cap="flat" cmpd="sng" algn="ctr">
                    <a:solidFill>
                        <a:schemeClr val="phClr"/>
                    </a:solidFill>
                    <a:prstDash val="solid"/>
                </a:ln>
                <a:ln w="38100" cap="flat" cmpd="sng" algn="ctr">
                    <a:solidFill>
                        <a:schemeClr val="phClr"/>
                    </a:solidFill>
                    <a:prstDash val="solid"/>
                </a:ln>
            </a:lnStyleLst>
            <a:effectStyleLst>
                <a:effectStyle>
                    <a:effectLst>
                        <a:outerShdw blurRad="40000" dist="20000" dir="5400000" rotWithShape="0">
                            <a:srgbClr val="000000">
                                <a:alpha val="38000"/>
                            </a:srgbClr>
                        </a:outerShdw>
                    </a:effectLst>
                </a:effectStyle>
                <a:effectStyle>
                    <a:effectLst>
                        <a:outerShdw blurRad="40000" dist="23000" dir="5400000" rotWithShape="0">
                            <a:srgbClr val="000000">
                                <a:alpha val="35000"/>
                            </a:srgbClr>
                        </a:outerShdw>
                    </a:effectLst>
                </a:effectStyle>
                <a:effectStyle>
                    <a:effectLst>
                        <a:outerShdw blurRad="40000" dist="23000" dir="5400000" rotWithShape="0">
                            <a:srgbClr val="000000">
                                <a:alpha val="35000"/>
                            </a:srgbClr>
                        </a:outerShdw>
                    </a:effectLst>
                    <a:scene3d>
                        <a:camera prst="orthographicFront">
                            <a:rot lat="0" lon="0" rev="0"/>
                        </a:camera>
                        <a:lightRig rig="threePt" dir="t">
                            <a:rot lat="0" lon="0" rev="1200000"/>
                        </a:lightRig>
                    </a:scene3d>
                    <a:sp3d>
                        <a:bevelT w="63500" h="25400"/>
                    </a:sp3d>
                </a:effectStyle>
            </a:effectStyleLst>
            <a:bgFillStyleLst>
                <a:solidFill>
                    <a:schemeClr val="phClr"/>
                </a:solidFill>
                <a:gradFill rotWithShape="1">
                    <a:gsLst>
                        <a:gs pos="0">
                            <a:schemeClr val="phClr">
                                <a:tint val="40000"/>
                                <a:satMod val="350000"/>
                            </a:schemeClr>
                        </a:gs>
                        <a:gs pos="40000">
                            <a:schemeClr val="phClr">
                                <a:tint val="45000"/>
                                <a:shade val="99000"/>
                                <a:satMod val="350000"/>
                            </a:schemeClr>
                        </a:gs>
                        <a:gs pos="100000">
                            <a:schemeClr val="phClr">
                                <a:shade val="20000"/>
                                <a:satMod val="255000"/>
                            </a:schemeClr>
                        </a:gs>
                    </a:gsLst>
                    <a:path path="circle">
                        <a:fillToRect l="50000" t="-80000" r="50000" b="180000"/>
                    </a:path>
                </a:gradFill>
                <a:gradFill rotWithShape="1">
                    <a:gsLst>
                        <a:gs pos="0">
                            <a:schemeClr val="phClr">
                                <a:tint val="80000"/>
                                <a:satMod val="300000"/>
                            </a:schemeClr>
                        </a:gs>
                        <a:gs pos="100000">
                            <a:schemeClr val="phClr">
                                <a:shade val="30000"/>
                                <a:satMod val="200000"/>
                            </a:schemeClr>
                        </a:gs>
                    </a:gsLst>
                    <a:path path="circle">
                        <a:fillToRect l="50000" t="50000" r="50000" b="50000"/>
                    </a:path>
                </a:gradFill>
            </a:bgFillStyleLst>
        </a:fmtScheme>
    </a:themeElements>
    <a:objectDefaults>
        <a:spDef>
            <a:spPr/>
            <a:bodyPr/>
            <a:lstStyle/>
            <a:style>
                <a:lnRef idx="1">
                    <a:schemeClr val="accent1"/>
                </a:lnRef>
                <a:fillRef idx="3">
                    <a:schemeClr val="accent1"/>
                </a:fillRef>
                <a:effectRef idx="2">
                    <a:schemeClr val="accent1"/>
                </a:effectRef>
                <a:fontRef idx="minor">
                    <a:schemeClr val="lt1"/>
                </a:fontRef>
            </a:style>
        </a:spDef>
        <a:lnDef>
            <a:spPr/>
            <a:bodyPr/>
            <a:lstStyle/>
            <a:style>
                <a:lnRef idx="2">
                    <a:schemeClr val="accent1"/>
                </a:lnRef>
                <a:fillRef idx="0">
                    <a:schemeClr val="accent1"/>
                </a:fillRef>
                <a:effectRef idx="1">
                    <a:schemeClr val="accent1"/>
                </a:effectRef>
                <a:fontRef idx="minor">
                    <a:schemeClr val="tx1"/>
                </a:fontRef>
            </a:style>
        </a:lnDef>
    </a:objectDefaults>
    <a:extraClrSchemeLst/>
</a:theme>
"""
        self.Write(data: style, tofile: "\(BasePath)/xl/theme/theme1.xml")
        
        
        self.Write(data: self.rels, tofile: "\(BasePath)/_rels/.rels")
        self.Write(data: self.SharedStrings, tofile: "\(BasePath)/xl/sharedStrings.xml")
        self.Write(data: self.StyleStrings, tofile: "\(BasePath)/xl/styles.xml")
        self.Write(data: self.ContentTypesStrings, tofile: "\(BasePath)/[Content_Types].xml")
        self.Write(data: self.WorkBookXmlRelsStrings, tofile: "\(BasePath)/xl/_rels/workbook.xml.rels")
        self.Write(data: self.WorkBookXmlStrings, tofile: "\(BasePath)/xl/workbook.xml")
        
        var i = 1
        for sheet in Sheets {
            
            self.Write(data: sheet.xml!, tofile: "\(BasePath)/xl/worksheets/sheet\(i).xml")
            
            if let drawingsxml = sheet.drawingsxml {
                self.Write(data: drawingsxml, tofile: "\(BasePath)/xl/drawings/drawing\(i).xml")
            }
            if let drawingsxmlrels = sheet.drawingsxmlrels {
                self.Write(data: drawingsxmlrels, tofile: "\(BasePath)/xl/drawings/_rels/drawing\(i).xml.rels")
            }
            
            var rels = self.HeadSheedXML
            if let drawingsSheetrels = sheet.drawingsSheetrels {
                rels = "\(rels)\(drawingsSheetrels)"
            }
            rels = "\(rels)\(self.HeadSheedXMLEnd)"
            self.Write(data: rels, tofile: "\(BasePath)/xl/worksheets/_rels/sheet\(i).xml.rels")
            
            i += 1
        }
        
        
        let filepath = "\(CachePath)/\(filename)"
        let fileManager = FileManager()
        do {
            try fileManager.zipItem(at: URL(fileURLWithPath: BasePath), to: URL(fileURLWithPath: filepath), shouldKeepParent: false)
        } catch {
            print("Creation of ZIP archive failed with error:\(error)")
        }
        self.RemoveFile(path: BasePath)
        return filepath
    }
    
    
    /// write xlxs file and return path
    public func save(_ filename:String) -> String {
        self.BuildStyles()
        self.BuildSheets()
        self.BuildMediaDrawings()
        return self.preparefiles(for: filename)
    }
    
    /// generate example xlsx file
    static public func test() -> Bool {
        let book = XWorkBook()
        
        let testBundle = Bundle(for: self).resourcePath!
        let pathBundle = testBundle.appending("/SwiftXLSX_SwiftXLSX.bundle")
        let BundleTest = Bundle(path: pathBundle)
        
        var icons:[ImageClass] = []
        for iconname in  ["green","blue","yellow","pin"] {
            var img:ImageClass?
#if os(macOS)
            img = BundleTest?.image(forResource: iconname)
#else
            img = ImageClass(named: iconname, in: BundleTest, compatibleWith: nil)
#endif
            if let img = img {
                icons.append(img)
            }
        }
#if os(macOS)
        let logoicon = BundleTest?.image(forResource: "swiftxlsxlogo")
#else
        let logoicon = ImageClass(named: "swiftxlsxlogo", in: BundleTest, compatibleWith: nil)
#endif
        
        
        let color:[ColorClass] = [.darkGray, .green, .lightGray, .orange, .systemPink, .cyan, .purple, .magenta, .blue]
        var colortext:[ColorClass] = [.darkGray, .black, .white]
#if os(macOS)
        colortext.append(contentsOf:[.textColor,.textBackgroundColor])
#else
        colortext.append(contentsOf: [.darkText,.lightText])
#endif
        
        func GetRandomFont() -> XFontName {
            let cases = XFontName.allCases
            return cases[Int.random(in: 0..<cases.count)]
        }
        
        
        var sheet = book.NewSheet("Invoice")
        
        var cell = sheet.AddCell(XCoords(row: 1, col: 1))
        
        cell.value = .icon(XImageCell(key: XImages.append(with: logoicon!)!, size: CGSize(width: 200, height: 75)))
        cell.alignmentHorizontal = .center
        
        
        
        cell = sheet.AddCell(XCoords(row: 2, col: 6))
        cell.Cols(txt: .white, bg: .systemOrange)
        cell.value = .text("INVOICE")
        cell.Font = XFont(.TrebuchetMS, 16,true)
        cell.alignmentHorizontal = .center
        
        cell = sheet.AddCell(XCoords(row: 3, col: 6))
        cell.Cols(txt: .white, bg: .systemOrange)
        cell.value = .text("#12345")
        cell.Font = XFont(.TrebuchetMS, 12,true)
        cell.alignmentHorizontal = .left
        
        
        cell = sheet.AddCell(XCoords(row: 4, col: 1))
        cell.value = .text("[Address Line 1]")
        
        cell = sheet.AddCell(XCoords(row: 5, col: 1))
        cell.value = .text("[Address Line 2]")
        
        cell = sheet.AddCell(XCoords(row: 7, col: 1))
        cell.color = .systemOrange
        cell.value = .text("Bill To:")
        cell.Font = XFont(.TrebuchetMS, 12,true)
        
        cell = sheet.AddCell(XCoords(row: 8, col: 1))
        cell.value = .text("[Address Line 1]")
        
        cell = sheet.AddCell(XCoords(row: 9, col: 1))
        cell.value = .text("[Address Line 2]")
        
        cell = sheet.AddCell(XCoords(row: 10, col: 1))
        cell.value = .text("[Address Line 3]")
        
        /// date
        cell = sheet.AddCell(XCoords(row: 13, col: 1))
        cell.color = .systemOrange
        cell.value = .text("Invoice Date")
        cell.Font = XFont(.TrebuchetMS, 12,true)
        
        cell = sheet.AddCell(XCoords(row: 14, col: 1))
        cell.value = .text("01/22/2022")
        
        /// term
        cell = sheet.AddCell(XCoords(row: 13, col: 2))
        
        cell.value = .text("Terms")
        cell.Font = XFont(.TrebuchetMS, 12,true)
        
        cell = sheet.AddCell(XCoords(row: 14, col: 2))
        cell.value = .text("30 days")
        
        /// Due Date
        cell = sheet.AddCell(XCoords(row: 13, col: 3))
        cell.color = .systemOrange
        cell.value = .text("Due Date")
        cell.Font = XFont(.TrebuchetMS, 12,true)
        
        cell = sheet.AddCell(XCoords(row: 14, col: 3))
        cell.value = .text("02/20/2022")
        
        /// table
        /// title
        var line = 16
        cell = sheet.AddCell(XCoords(row: line, col: 1))
        cell.Cols(txt: .white, bg: .systemOrange)
        cell.Border = true
        cell.value = .text("Description")
        
        cell = sheet.AddCell(XCoords(row: line, col: 4))
        cell.Cols(txt: .white, bg: .systemOrange)
        cell.Border = true
        cell.value = .text("Qty")
        cell.Font = XFont(.TrebuchetMS, 10,true)
        
        cell = sheet.AddCell(XCoords(row: line, col: 5))
        cell.Cols(txt: .white, bg: .systemOrange)
        cell.Border = true
        cell.value = .text("Unit Price")
        cell.Font = XFont(.TrebuchetMS, 10,true)
        
        cell = sheet.AddCell(XCoords(row: line, col: 6))
        cell.Cols(txt: .white, bg: .systemOrange)
        cell.Border = true
        cell.value = .text("Amount")
        cell.Font = XFont(.TrebuchetMS, 10,true)
        
        /// line
        line += 1
        cell = sheet.AddCell(XCoords(row: line, col: 1))
        cell.Border = true
        cell.value = .text("item #1")
        
        cell = sheet.AddCell(XCoords(row: line, col: 4))
        cell.Border = true
        cell.value = .double(3)
        cell.alignmentHorizontal = .right
        
        cell = sheet.AddCell(XCoords(row: line, col: 5))
        cell.Border = true
        cell.value = .double(50)
        cell.alignmentHorizontal = .right
        
        cell = sheet.AddCell(XCoords(row: line, col: 6))
        cell.Border = true
        cell.value = .double(150)
        cell.alignmentHorizontal = .right
        
        /// line
        line += 1
        cell = sheet.AddCell(XCoords(row: line, col: 1))
        
        var bgColor:ColorClass
#if os(macOS)
        bgColor = .lightGray
#else
        if #available(iOS 13.0, *) {
            bgColor = .lightGray
        } else {
            bgColor = .lightGray
        }
#endif
        cell.Cols(txt: .black, bg: bgColor)
        cell.Border = true
        cell.value = .text("item #2")
        
        cell = sheet.AddCell(XCoords(row: line, col: 4))
        cell.Cols(txt: .black, bg: bgColor)
        cell.Border = true
        cell.value = .double(2)
        cell.alignmentHorizontal = .right
        
        cell = sheet.AddCell(XCoords(row: line, col: 5))
        cell.Cols(txt: .black, bg: bgColor)
        cell.Border = true
        cell.value = .double(100)
        cell.alignmentHorizontal = .right
        
        cell = sheet.AddCell(XCoords(row: line, col: 6))
        cell.Cols(txt: .black, bg: bgColor)
        cell.Border = true
        cell.value = .double(200)
        cell.alignmentHorizontal = .right
        
        /// line
        line += 1
        cell = sheet.AddCell(XCoords(row: line, col: 1))
        cell.Border = true
        cell.value = .text("item #3")
        
        cell = sheet.AddCell(XCoords(row: line, col: 4))
        cell.Border = true
        cell.value = .double(4)
        cell.alignmentHorizontal = .right
        
        cell = sheet.AddCell(XCoords(row: line, col: 5))
        cell.Border = true
        cell.value = .double(200)
        cell.alignmentHorizontal = .right
        
        cell = sheet.AddCell(XCoords(row: line, col: 6))
        cell.Border = true
        cell.value = .double(800)
        cell.alignmentHorizontal = .right
        
        line += 2
        
        cell = sheet.AddCell(XCoords(row: line, col: 1))
        cell.value = .text("Thank you for your business!")
        cell.Font = XFont(.TrebuchetMS, 10, false, true)
        cell.alignmentHorizontal = .left
        
        cell = sheet.AddCell(XCoords(row: line, col: 5))
        cell.Cols(txt: .white, bg: .systemOrange)
        cell.value = .text("Total")
        cell.Font = XFont(.TrebuchetMS, 11, true)
        cell.alignmentHorizontal = .left
        
        cell = sheet.AddCell(XCoords(row: line, col: 6))
        cell.Cols(txt: .white, bg: .systemOrange)
        cell.value = .double(1100)
        cell.Font = XFont(.TrebuchetMS, 11, true)
        cell.alignmentHorizontal = .right
        
        line += 2
        
        cell = sheet.AddCell(XCoords(row: line, col: 1))
        cell.value = .text("Payment Options")
        cell.Font = XFont(.TrebuchetMS, 12, true, false)
        cell.alignmentHorizontal = .left
        
        line += 1
        
        cell = sheet.AddCell(XCoords(row: line, col: 1))
        cell.value = .text("Enter PayPal email address or bank account number here")
        cell.Font = XFont(.TrebuchetMS, 10, false, true)
        cell.alignmentHorizontal = .left
        
        line += 2
        
        cell = sheet.AddCell(XCoords(row: line, col: 1))
        cell.value = .icon(XImageCell(key: XImages.append(with: logoicon!)!, size: CGSize(width: 200, height: 75)))
        cell.alignmentHorizontal = .center
        
        cell = sheet.AddCell(XCoords(row: line, col: 3))
        cell.value = .icon(XImageCell(key: XImages.append(with: logoicon!)!, size: CGSize(width: 400, height: 150)))
        cell.alignmentHorizontal = .center
        
        
        
        line += 7
        
        cell = sheet.AddCell(XCoords(row: line, col: 1))
        cell.value = .text("example of inserting an image of a different size")
        cell.Font = XFont(.TrebuchetMS, 10, false, true)
        cell.alignmentHorizontal = .left
        sheet.MergeRect(XRect(line, 1, 5, 1))
        
        sheet.MergeRect(XRect(2, 1, 5, 1))
        sheet.MergeRect(XRect(3, 1, 5, 1))
        sheet.MergeRect(XRect(4, 1, 5, 1))
        sheet.MergeRect(XRect(5, 1, 5, 1))
        
        sheet.MergeRect(XRect(16, 1, 3, 1))
        sheet.MergeRect(XRect(17, 1, 3, 1))
        sheet.MergeRect(XRect(18, 1, 3, 1))
        sheet.MergeRect(XRect(19, 1, 3, 1))
        
        sheet.MergeRect(XRect(23, 1, 3, 1))
        sheet.MergeRect(XRect(24, 1, 3, 1))
        
        
        sheet.ForColumnSetWidth(1, 100)
        sheet.ForColumnSetWidth(2, 70)
        sheet.ForColumnSetWidth(3, 60)
        sheet.ForColumnSetWidth(4, 70)
        sheet.ForColumnSetWidth(5, 70)
        sheet.ForColumnSetWidth(6, 90)
        
        
        sheet = book.NewSheet("Icons")
        for col in 1...20 {
            sheet.ForColumnSetWidth(col,20)
            for row in 1...20 {
                let cell = sheet.AddCell(XCoords(row: row, col: col))
                cell.value = .icon(XImageCell(key: XImages.append(with: XImage(with: icons[Int.random(in: 0..<icons.count)])!), size: CGSize(width: 20, height: 20)))
            }
        }
        
        
        sheet = book.NewSheet("Perfomance Sheet")
        for col in 1...20 {
            sheet.ForColumnSetWidth(col,Int.random(in: 50..<100))
            for row in 1...1000 {
                let cell = sheet.AddCell(XCoords(row: row, col: col))
                cell.value = .integer(Int.random(in: 100..<200000))
                cell.Font = XFont(GetRandomFont(), Int.random(in: 10..<20))
                cell.color = colortext[Int.random(in: 0..<colortext.count)]
                cell.colorbackground = color[Int.random(in: 0..<color.count)]
                cell.Border = true
                cell.alignmentHorizontal = .center
                cell.alignmentVertical = .center
            }
        }
        
        
        
        
        let fileid = book.save("example.xlsx")
        print("<<<File XLSX generated!>>>")
        print("\(fileid)")
        return true
    }
}

extension XWorkBook: Sequence {
    public func makeIterator() -> Array<XSheet>.Iterator {
        return Sheets.makeIterator()
    }
}

#if os(macOS)
fileprivate extension NSFont {
    /// Calculate size text for current font
    func Rectfor(_ str:String)-> CGSize {
        let fontAttributes = [NSAttributedString.Key.font: self]
        let size = (str as NSString).size(withAttributes: fontAttributes)
        return size
    }
}
#else
fileprivate extension UIFont {
    /// Calculate size text for current font
    func Rectfor(_ str:String)-> CGSize {
        let fontAttributes = [NSAttributedString.Key.font: self]
        let size = (str as NSString).size(withAttributes: fontAttributes)
        return size
    }
}
#endif


fileprivate extension String{
    func XmlPrep() -> String
    {
        let sm = NSMutableString()
        for (_, char) in self.enumerated() {
            switch char {
            case "&":
                sm.append("&amp;")
            case "\"":
                sm.append("&quot;")
            case "'":
                sm.append("&#x27;")
            case ">":
                sm.append("&gt;")
            case "<":
                sm.append("&lt;")
            default:
                sm.append(String(char))
            }
        }
        return String(sm)
    }
    
    func XSheetTitle() -> String
    {
        let sm = NSMutableString()
        for (_, char) in self.enumerated() {
            switch char {
            case ":":
                sm.append(" ")
            case "\\":
                sm.append(" ")
            case "\"":
                sm.append(" ")
            case "?":
                sm.append(" ")
            case "*":
                sm.append(" ")
            case "[":
                sm.append(" ")
            case "]":
                sm.append(" ")
            default:
                sm.append(String(char))
            }
        }
        return String(sm)
    }
}

extension ColorClass {
    static var hexdict:[UInt64:String] = [:]
    /// encode color to HEX format AARRGGBB use cache for optimization
    var Hex:String?{
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
#if os(macOS)
        let rgb = self.usingColorSpace(NSColorSpace.deviceRGB) ?? ColorClass.gray
        rgb.getRed(&r, green: &g, blue: &b, alpha: &a)
#else
        self.getRed(&r, green: &g, blue: &b, alpha: &a)
#endif
        
        let ri = lroundf(Float(r) * 255)
        let gi = lroundf(Float(g) * 255)
        let bi = lroundf(Float(b) * 255)
        let ai = lroundf(Float(a) * 255)
        
        let idcolor = UInt64(ai)*1000000000+UInt64(ri)*1000000+UInt64(gi)*1000+UInt64(bi)
        if let hexcol = ColorClass.hexdict[idcolor] {
            return hexcol
        }else{
            let hexcolgen = String(format: "%02lX%02lX%02lX%02lX",ai,ri,gi,bi)
            ColorClass.hexdict[idcolor] = hexcolgen
            return hexcolgen
        }
    }
}
