//
//  DataManager.swift
//  2330_PEBand
//
//  Created by 蔡念澄 on 2022/6/25.
//

import UIKit

class DataManager {
    static let shared = DataManager()
    var peRatios:[String] = []
    
    func fetchJSON(completion: @escaping (Result<[DataModel], Error>) -> Void) {
        if let url = URL(string: "https://api.nstock.tw/v2/per-river/interview?stock_id=2330") {
            let request = URLRequest(url: url)
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let data = data {
                    do {
                        let decoder = JSONDecoder()
                        let jsonData = try decoder.decode(JSONData.self, from: data)
                        let allData = self.parseJSON(jsonData)
                        completion(.success(allData))
                    } catch {
                        completion(.failure(error))
                    }
                } else if let error = error {
                    completion(.failure(error))
                }
            }.resume()
        }
    }
    
    func parseJSON(_ jsonData: JSONData) -> [DataModel] {
        var allData = [DataModel]()
        for record in jsonData.data {
            if peRatios.isEmpty {
                for ratio in record.本益比基準 {
                    peRatios.append(ratio+"倍")
                }
            }
            for monthlyData in record.河流圖資料.reversed() {
                let data = DataModel(
                    month: Double(monthlyData.年月)!,
                    monthLabel: String(monthlyData.年月[...monthlyData.年月.index(monthlyData.年月.startIndex, offsetBy: 3)]
                                  + "/" + monthlyData.年月[monthlyData.年月.index(monthlyData.年月.endIndex, offsetBy: -2)...]),
                    monthlyClosingPrice: Double(monthlyData.月平均收盤價)!,
                    peList: monthlyData.本益比股價基準.map{Double($0)!}
                )
                allData.append(data)
            }
        }
        return allData
    }
}
