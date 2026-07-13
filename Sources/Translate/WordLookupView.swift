import SwiftUI
import UIKit

struct WordLookupView: UIViewControllerRepresentable {
    let term: String

    func makeUIViewController(context: Context) -> UIReferenceLibraryViewController {
        UIReferenceLibraryViewController(term: term)
    }

    func updateUIViewController(_ uiViewController: UIReferenceLibraryViewController, context: Context) {}
}

func canLookUp(term: String) -> Bool {
    UIReferenceLibraryViewController.dictionaryHasDefinition(forTerm: term)
}
