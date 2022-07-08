//
//  ViewController.swift
//  2330_PEBand
//
//  Created by 蔡念澄 on 2022/6/25.
//

import UIKit
import Charts
import TinyConstraints

class ViewController: UIViewController, ChartViewDelegate {
    var allData: [DataModel] = []
    var monthlyClosingPrices: [ChartDataEntry] = []
    var peLines: [Int:[ChartDataEntry]] = [:]
    
    var months: [String] = []
    
    let lineChartView = LineChartView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        DataManager.shared.fetchJSON { result in
            switch result {
            case .success(let allData):
                self.allData = allData
                self.setData()
                DispatchQueue.main.async {                    
                    self.setChart()
                }
            case .failure(let error):
                print(error)
            }
        }
    }
    
    func setData() {
        months = allData.map{$0.monthLabel}
        for i in 0..<allData.count {
            let dataEntryMCP = ChartDataEntry(x: Double(i), y: allData[i].monthlyClosingPrice) //, data: allData[i].monthLabel as AnyObject)
            monthlyClosingPrices.append(dataEntryMCP)
            
            for j in 0...5 {
                let dataEntry = ChartDataEntry(x: Double(i), y: allData[i].peList[j])
                if peLines[j] != nil {
                    peLines[j]!.append(dataEntry)
                } else {
                    peLines[j] = [dataEntry]
                }
            }
        }

        let setMCP = LineChartDataSet(entries: monthlyClosingPrices, label: "股價\(allData.last?.monthlyClosingPrice ?? 0)")
        setMCP.lineWidth = 3
        var dataSets = [setMCP]
        for k in 0...5 {
            DataManager.shared.peRatios[k] += "\(allData.last?.peList[k] ?? 0)"
            dataSets.append(LineChartDataSet(entries: peLines[k]!, label: DataManager.shared.peRatios[k]))
        }
        let colors:[UIColor] = [.red, .green, .blue, .systemBlue, .yellow, .orange, .systemRed]
        for i in 0..<dataSets.count{
            dataSets[i].drawCirclesEnabled = false
            dataSets[i].setColor(colors[i])
            
            if i > 1 {
                dataSets[i].drawFilledEnabled = true
                dataSets[i].fillFormatter = AreaFillFormatter(fillLineDataSet: dataSets[i-1])
                dataSets[i].fillColor = colors[i]
            }
        }

        let data = LineChartData(dataSets: dataSets)
        data.setDrawValues(false)
        
        lineChartView.data = data
    }
    
    func setChart() {
        lineChartView.leftAxis.enabled = false
        let yAxis = lineChartView.rightAxis
        yAxis.labelPosition = .outsideChart
        
        lineChartView.xAxis.labelPosition = .bottom
        lineChartView.xAxis.valueFormatter = IndexAxisValueFormatter(values: months)
        self.view.addSubview(lineChartView)
        lineChartView.centerInSuperview()
        lineChartView.width(to: self.view)
        lineChartView.heightToWidth(of: self.view)
        
        // Set the custom line chart renderer
        lineChartView.renderer = CustomLineChartRenderer(dataProvider: lineChartView, animator: lineChartView.chartAnimator, viewPortHandler: lineChartView.viewPortHandler)
        
        lineChartView.animate(xAxisDuration: 0.5)
    }
}

class AreaFillFormatter: FillFormatter {

    var fillLineDataSet: LineChartDataSet?
    
    init(fillLineDataSet: LineChartDataSet) {
        self.fillLineDataSet = fillLineDataSet
    }
    
    public func getFillLinePosition(dataSet: LineChartDataSetProtocol, dataProvider: LineChartDataProvider) -> CGFloat {
        return 0.0
    }
    
    public func getFillLineDataSet() -> LineChartDataSet {
        return fillLineDataSet ?? LineChartDataSet()
    }
    
}

class CustomLineChartRenderer: LineChartRenderer {
    
    override open func drawLinearFill(context: CGContext, dataSet: LineChartDataSetProtocol, trans: Transformer, bounds: XBounds) {
        guard let dataProvider = dataProvider else { return }
        
        let areaFillFormatter = dataSet.fillFormatter as? AreaFillFormatter
        
        let filled = generateFilledPath(
            dataSet: dataSet,
            fillMin: dataSet.fillFormatter?.getFillLinePosition(dataSet: dataSet, dataProvider: dataProvider) ?? 0.0,
            fillLineDataSet: areaFillFormatter?.getFillLineDataSet(),
            bounds: bounds,
            matrix: trans.valueToPixelMatrix)
        
        if dataSet.fill != nil
        {
            drawFilledPath(context: context, path: filled, fill: dataSet.fill!, fillAlpha: dataSet.fillAlpha)
        }
        else
        {
            drawFilledPath(context: context, path: filled, fillColor: dataSet.fillColor, fillAlpha: dataSet.fillAlpha)
        }
    }
    
    fileprivate func generateFilledPath(dataSet: LineChartDataSetProtocol, fillMin: CGFloat, fillLineDataSet: LineChartDataSetProtocol?, bounds: XBounds, matrix: CGAffineTransform) -> CGPath
    {
        let phaseY = animator.phaseY
        let isDrawSteppedEnabled = dataSet.mode == .stepped
        let matrix = matrix
        
        var e: ChartDataEntry!
        var fillLineE: ChartDataEntry?
        
        let filled = CGMutablePath()
        
        e = dataSet.entryForIndex(bounds.min)
        fillLineE = fillLineDataSet?.entryForIndex(bounds.min)
        
        if e != nil
        {
            if let fillLineE = fillLineE
            {
                filled.move(to: CGPoint(x: CGFloat(e.x), y: CGFloat(fillLineE.y * phaseY)), transform: matrix)
            }
            else
            {
                filled.move(to: CGPoint(x: CGFloat(e.x), y: fillMin), transform: matrix)
            }
            
            filled.addLine(to: CGPoint(x: CGFloat(e.x), y: CGFloat(e.y * phaseY)), transform: matrix)
        }
        
        // Create the path for the data set entries
        for x in stride(from: (bounds.min + 1), through: bounds.range + bounds.min, by: 1)
        {
            guard let e = dataSet.entryForIndex(x) else { continue }
            
            if isDrawSteppedEnabled
            {
                guard let ePrev = dataSet.entryForIndex(x-1) else { continue }
                filled.addLine(to: CGPoint(x: CGFloat(e.x), y: CGFloat(ePrev.y * phaseY)), transform: matrix)
            }
            
            filled.addLine(to: CGPoint(x: CGFloat(e.x), y: CGFloat(e.y * phaseY)), transform: matrix)
        }
        
        // Draw a path to the start of the fill line
        e = dataSet.entryForIndex(bounds.range + bounds.min)
        fillLineE = fillLineDataSet?.entryForIndex(bounds.range + bounds.min)
        if e != nil
        {
            if let fillLineE = fillLineE
            {
                filled.addLine(to: CGPoint(x: CGFloat(e.x), y: CGFloat(fillLineE.y * phaseY)), transform: matrix)
            }
            else
            {
                filled.addLine(to: CGPoint(x: CGFloat(e.x), y: fillMin), transform: matrix)
            }
        }
        
        // Draw the path for the fill line (backwards)
        if let fillLineDataSet = fillLineDataSet {
            for x in stride(from: (bounds.min + 1), through: bounds.range + bounds.min, by: 1).reversed()
            {
                guard let e = fillLineDataSet.entryForIndex(x) else { continue }
                
                if isDrawSteppedEnabled
                {
                    guard let ePrev = fillLineDataSet.entryForIndex(x-1) else { continue }
                    filled.addLine(to: CGPoint(x: CGFloat(e.x), y: CGFloat(ePrev.y * phaseY)), transform: matrix)
                }

                filled.addLine(to: CGPoint(x: CGFloat(e.x), y: CGFloat(e.y * phaseY)), transform: matrix)
            }
        }
        
        filled.closeSubpath()
        
        return filled
    }
}
