
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
        textField.font = UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline)
        textField.placeholder = "Google Image Search"
        textField.textAlignment = .Center

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
	
		DynamicProperty(object: cell.imageView, keyPath: "image") <~ nilThenImageUntilReuse
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
