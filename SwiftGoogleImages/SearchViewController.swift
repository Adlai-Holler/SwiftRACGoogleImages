
import UIKit
import ReactiveCocoa

class SearchViewController: UICollectionViewController {
	let viewModel = SearchViewModel()
	let textField: UITextField
	
	init() {
		let flow = UICollectionViewFlowLayout()
		let padding: CGFloat = 1 / UIScreen.mainScreen().scale
		let itemDim = UIScreen.mainScreen().bounds.width / 3 - padding * 2
		flow.itemSize = CGSize(width: itemDim, height: itemDim)
		flow.minimumInteritemSpacing = padding
		flow.minimumLineSpacing = padding
		textField = UITextField(frame: CGRect(x: 0, y: 0, width: 200, height: 21))
		super.init(collectionViewLayout: flow)

		navigationItem.titleView = textField
		(textSignal(textField)
			|> throttle(1, onScheduler: QueueScheduler()))
			.start(next: {
				self.viewModel.searchAction.apply($0).start()
			})
	}

	required init(coder aDecoder: NSCoder) {
	    fatalError("init(coder:) has not been implemented")
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		let collectionView = self.collectionView!
		(viewModel.latestResults.producer
			|> takeUntil(deallocSignal(collectionView))
			|> skip(1))
			.start(next: {_ in
			collectionView.reloadData()
		})
		
		collectionView.backgroundColor = UIColor.whiteColor()
		collectionView.alwaysBounceVertical = true
		collectionView.registerClass(ImageCell.self, forCellWithReuseIdentifier: "cellID")
		textField.becomeFirstResponder()
	}
	
	override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return viewModel.latestResults.value.count
	}

	override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCellWithReuseIdentifier("cellID", forIndexPath: indexPath) as! ImageCell
		
		let item = viewModel.latestResults.value[indexPath.item]
		let imageProducer = NSURLSession.sharedSession().rac_dataWithRequest(NSURLRequest(URL: item.thumbURL))
			|> map {data, _ in UIImage(data: data)! }
			|> catch {_ in SignalProducer<UIImage, NoError>(value: UIImage()) }
		
		let prepForReuse = cell.rac_prepareForReuseSignal.toSignalProducer()
			|> map {_ in () }
			|> catch {_ in SignalProducer<(), NoError>.empty }
		
		let imageUntilReuse = imageProducer
			|> takeUntil(prepForReuse)
			|> observeOn(UIScheduler())

		let nilThenImageUntilReuse = SignalProducer<AnyObject?, NoError>(value: nil)
			|> concat(imageUntilReuse |> map { $0 as AnyObject? })
	
		// TODO: why doesn't this work?
//		DynamicProperty(object: cell.imageView, keyPath: "image") <~ nilThenImageUntilReuse
		
		// manually bind to property works
		nilThenImageUntilReuse.start(next: { imageOrNil in
			cell.imageView.image = imageOrNil as! UIImage?
		})
		return cell
	}
}

class ImageCell: UICollectionViewCell {
	let imageView: UIImageView
	override init(frame: CGRect) {
		imageView = UIImageView()
		imageView.clipsToBounds = true
		imageView.contentMode = .ScaleAspectFill
		imageView.backgroundColor = UIColor.lightGrayColor()
		super.init(frame: frame)
		imageView.frame = contentView.bounds
		contentView.addSubview(imageView)
	}

	required init(coder aDecoder: NSCoder) {
	    fatalError("init(coder:) has not been implemented")
	}
}

struct GoogleImageResult {
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

class SearchViewModel {
	let searchAction: Action<String, [GoogleImageResult], NSError>
	let latestResults: PropertyOf<[GoogleImageResult]>
	init() {
		searchAction = Action { input in
			let queryString = input.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)!
			// TODO: add your IP address here http://whatismyip.com yes I'm that lazy
			let myIP: String = nil
			let searchURL = NSURL(string: "https://ajax.googleapis.com/ajax/services/search/images?v=1.0&q=\(queryString)&userip=\(myIP)&rsz=8")!
			let request = NSMutableURLRequest(URL: searchURL)
			request.setValue("http://myToyApp.com", forHTTPHeaderField: "Referer")
			return NSURLSession.sharedSession().rac_dataWithRequest(request)
			|> map { data, _ in
				let dict = NSJSONSerialization.JSONObjectWithData(data, options: .allZeros, error: nil)! as! [String: AnyObject]
				let resultDicts = ((dict["responseData"]! as! [String: AnyObject])["results"]! as! [[String: String]])
				return resultDicts.map { GoogleImageResult(dictionary: $0) }
			}
		}
		let _latestResults = MutableProperty<[GoogleImageResult]>([])
		latestResults = PropertyOf(_latestResults)
		_latestResults <~ (searchAction.values |> observeOn(UIScheduler()))
	}
}

// MARK: Utilities

func deallocSignal(object: NSObject) -> SignalProducer<(), NoError> {
	return object.rac_willDeallocSignal().toSignalProducer()
		|> map {_ in () }
		|> catch {_ in SignalProducer<(), NoError>.empty }
}

func textSignal(textField: UITextField) -> SignalProducer<String, NoError> {
	return textField.rac_textSignal().toSignalProducer()
		|> map { $0! as! String }
		|> catch {_ in SignalProducer(value: "") }
}
