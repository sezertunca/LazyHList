import SwiftUI
import UIKit

struct LazyHList<Collections, CellContent>: UIViewControllerRepresentable where
    Collections : RandomAccessCollection,
    Collections.Index == Int,
    Collections.Element : RandomAccessCollection,
    Collections.Element.Index == Int,
    Collections.Element.Element : Identifiable,
    CellContent : View
{
    
    typealias Row = Collections.Element
    typealias Data = Row.Element
    typealias ContentForData = (Data) -> CellContent
    typealias ScrollDirection = UICollectionView.ScrollDirection
    typealias SizeForData = (Data) -> CGSize
    typealias CustomSizeForData = (UICollectionView, UICollectionViewLayout, Data) -> CGSize
    typealias RawCustomize = (UICollectionView) -> Void
    
    enum ContentSize {
        case fixed(CGSize)
        case variable(SizeForData)
        case crossAxisFilled(mainAxisLength: CGFloat)
        case custom(CustomSizeForData)
    }
    
    struct ItemSpacing : Hashable {
        var mainAxisSpacing: CGFloat
        var crossAxisSpacing: CGFloat
    }
    
    fileprivate let collections: Collections
    fileprivate let contentForData: ContentForData
    fileprivate let contentSize: ContentSize
    fileprivate let itemSpacing: ItemSpacing
    fileprivate let rawCustomize: RawCustomize?

    init(
        collections: Collections,
        contentSize: ContentSize = .crossAxisFilled(mainAxisLength: 40),
        itemSpacing: ItemSpacing = ItemSpacing(mainAxisSpacing: 10, crossAxisSpacing: 10),
        rawCustomize: RawCustomize? = nil,
        contentForData: @escaping ContentForData
    ) {
        self.collections = collections
        self.contentSize = contentSize
        self.itemSpacing = itemSpacing
        self.rawCustomize = rawCustomize
        self.contentForData = contentForData
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(view: self)
    }

    func makeUIViewController(context: Context) -> ViewController {
        let coordinator = context.coordinator
        let viewController = ViewController(coordinator: coordinator, scrollDirection: .horizontal)
        coordinator.viewController = viewController
        self.rawCustomize?(viewController.collectionView)
        return viewController
    }

    func updateUIViewController(_ uiViewController: ViewController, context: Context) {
        context.coordinator.view = self
        uiViewController.layout.scrollDirection = .horizontal
        self.rawCustomize?(uiViewController.collectionView)
        uiViewController.collectionView.reloadData()
        uiViewController.collectionView.showsHorizontalScrollIndicator = false
    }
}

extension LazyHList {
    
    init<Collection>(
        items: Collection,
        itemSize: ContentSize,
        itemSpacing: ItemSpacing = ItemSpacing(mainAxisSpacing: 0, crossAxisSpacing: 0),
        customize: RawCustomize? = nil,
        cell: @escaping ContentForData
    ) where Collections == [Collection] {
        self.init(
            collections: [items],
            contentSize: itemSize,
            itemSpacing: itemSpacing,
            rawCustomize: customize,
            contentForData: cell
        )
    }
}

extension LazyHList {
    
    fileprivate static var cellReuseIdentifier: String {
        return "HostedCollectionViewCell"
    }
}

extension LazyHList {

    final class ViewController : UIViewController {

        fileprivate let layout: UICollectionViewFlowLayout
        fileprivate let collectionView: UICollectionView

        init(coordinator: Coordinator, scrollDirection: ScrollDirection) {
            let layout = UICollectionViewFlowLayout()
            layout.scrollDirection = .horizontal
            self.layout = layout
            
            let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
            collectionView.backgroundColor = nil
            collectionView.register(HListCell.self, forCellWithReuseIdentifier: cellReuseIdentifier)
            collectionView.dataSource = coordinator
            collectionView.delegate = coordinator
            self.collectionView = collectionView
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) {
            fatalError("Can't build from interface.")
        }

        override func loadView() {
            self.view = self.collectionView
        }
    }
}

extension LazyHList {
    
    final class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
        
        fileprivate var view: LazyHList
        fileprivate var viewController: ViewController?

        init(view: LazyHList) {
            self.view = view
        }
        
        func numberOfSections(in collectionView: UICollectionView) -> Int {
            return self.view.collections.count
        }

        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            return self.view.collections[section].count
        }

        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellReuseIdentifier, for: indexPath) as! HListCell
            let data = self.view.collections[indexPath.section][indexPath.item]
            let content = self.view.contentForData(data)
            cell.provide(content)
            return cell
        }
        
        func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
            let cell = cell as! HListCell
            cell.attach(to: self.viewController!)
        }

        func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
            let cell = cell as! HListCell
            cell.detach()
        }
        
        func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
            switch self.view.contentSize {
            case .fixed(let size):
                return size
            case .variable(let sizeForData):
                let data = self.view.collections[indexPath.section][indexPath.item]
                return sizeForData(data)
            case .crossAxisFilled(let mainAxisLength):
                    return CGSize(width: mainAxisLength, height: collectionView.bounds.height)
            case .custom(let customSizeForData):
                let data = self.view.collections[indexPath.section][indexPath.item]
                return customSizeForData(collectionView, collectionViewLayout, data)
            }
        }

        func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
            return self.view.itemSpacing.mainAxisSpacing
        }

        func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
            return self.view.itemSpacing.crossAxisSpacing
        }
    }
}

private extension LazyHList {
    
    final class HListCell : UICollectionViewCell {
        
        var viewController: UIHostingController<CellContent>?

        func provide(_ content: CellContent) {
            if let viewController = self.viewController {
                viewController.rootView = content
            }
            else {
                let hostingController = UIHostingController(rootView: content)
                hostingController.view.backgroundColor = nil
                self.viewController = hostingController
            }
        }
        
        func attach(to parentController: UIViewController) {
            let hostedController = self.viewController!
            let hostedView = hostedController.view!
            let contentView = self.contentView
            parentController.addChild(hostedController)
            hostedView.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(hostedView)
            hostedView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor).isActive = true
            hostedView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor).isActive = true
            hostedView.topAnchor.constraint(equalTo: contentView.topAnchor).isActive = true
            hostedView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor).isActive = true
            hostedController.didMove(toParent: parentController)
        }
        
        func detach() {
            let hostedController = self.viewController!
            guard hostedController.parent != nil else { return }
            let hostedView = hostedController.view!
            hostedController.willMove(toParent: nil)
            hostedView.removeFromSuperview()
            hostedController.removeFromParent()
        }
    }
}

