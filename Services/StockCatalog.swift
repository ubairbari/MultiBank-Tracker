import Foundation

// MARK:  -  Stock Catalog  -  
struct StockCatalog {
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func loadStocks() throws -> [Stock] {
        guard let url = bundle.url(forResource: "stocks", withExtension: "json") else {
            throw CatalogError.missingResource
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([Stock].self, from: data)
    }
}

private enum CatalogError: LocalizedError {
    case missingResource

    var errorDescription: String? {
        switch self {
        case .missingResource: "The bundled stock catalog could not be found."
        }
    }
}
