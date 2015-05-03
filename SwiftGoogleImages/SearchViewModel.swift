import Foundation
import ReactiveCocoa

class SearchViewModel {
    typealias Response = (cursor: Cursor, results: [Result])
    
    enum Request {
        case NextPage
        case NewSearch(String)
    }
    
    struct Result {
        let thumbSize: CGSize
        let size: CGSize
        let visibleURL: String
        let thumbURL: NSURL
        let url: NSURL
        let imageID: String
        init(dictionary: [String: String]) {
            thumbSize = CGSize(width: dictionary["tbWidth"]!.toInt()!, height: dictionary["tbHeight"]!.toInt()!)
            size = CGSize(width: dictionary["width"]!.toInt()!, height: dictionary["height"]!.toInt()!)
            imageID = dictionary["imageId"]!
            thumbURL = NSURL(string: dictionary["tbUrl"]!)!
            visibleURL = dictionary["visibleUrl"]!
            url = NSURL(string: dictionary["visibleUrl"]!)!
        }
    }
    
    struct Cursor {
        let moreResultsURL: NSURL
        let currentPageIndex: Int?
        init(dictionary: [String: AnyObject]) {
            moreResultsURL = NSURL(string: dictionary["moreResultsUrl"] as! String)!
            currentPageIndex = dictionary["currentPageIndex"] as? Int
        }
    }
    
    let searchAction: Action<String, Response, NSError>
    let latestResults: PropertyOf<[Result]>
    init() {
        searchAction = Action { input in
            let queryString = input.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)!
            // TODO: add your IP address here http://whatismyip.com yes I'm that lazy
            let myIP: String = "50.174.9.0"
            let searchURL = NSURL(string: "https://ajax.googleapis.com/ajax/services/search/images?v=1.0&q=\(queryString)&userip=\(myIP)&rsz=8")!
            let request = NSMutableURLRequest(URL: searchURL)
            request.setValue("http://myToyApp.com", forHTTPHeaderField: "Referer")
            return NSURLSession.sharedSession().rac_dataWithRequest(request)
                |> map { data, _ in
                    let dict = NSJSONSerialization.JSONObjectWithData(data, options: .allZeros, error: nil)! as! [String: AnyObject]
                    println("******\nResponse: \(NSString(data: data, encoding: NSUTF8StringEncoding))")
                    let responseData = (dict["responseData"]! as! [String: AnyObject])
                    let cursorDict = responseData["cursor"]! as! [String: AnyObject]
                    let cursor = Cursor(dictionary: cursorDict)
                    let resultDicts = responseData["results"]! as! [[String: String]]
                    let results = resultDicts.map { Result(dictionary: $0) }
                    return (cursor, results)
            }
        }
        let _latestResults = MutableProperty<[Result]>([])
        latestResults = PropertyOf(_latestResults)
        _latestResults <~ (searchAction.values |> map { $0.results } |> observeOn(UIScheduler()))
    }
}
