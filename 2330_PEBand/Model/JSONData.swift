//
//  JSONData.swift
//  2330_PEBand
//
//  Created by 蔡念澄 on 2022/6/25.
//

import Foundation

struct JSONData: Codable {
    let data: [Data]
    
    struct Data: Codable {
        let 本益比基準: [String]
        let 河流圖資料: [MonthlyData]
        
        struct MonthlyData: Codable {
            let 年月: String
            let 月平均收盤價: String
            let 本益比股價基準: [String]
        }
    }
}
