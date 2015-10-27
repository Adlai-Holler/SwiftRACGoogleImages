
import Foundation
import ReactiveCocoa

func deallocSignal(object: NSObject) -> SignalProducer<(), NoError> {
    return object.rac_willDeallocSignal().toSignalProducer()
        .map {_ in () }
        .flatMapError {_ in SignalProducer<(), NoError>.empty }
}

func textSignal(textField: UITextField) -> SignalProducer<String, NoError> {
    return textField.rac_textSignal().toSignalProducer()
        .map { $0! as! String }
        .flatMapError {_ in SignalProducer(value: "") }
}