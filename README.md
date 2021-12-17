# LazyHList

LazyVStack and LazyHStack does load content lazly however they do not use dequeeing logic. If you have thousands of views, SwiftUI will create and keep them all in memory.

LazyHList uses CollectionView under the hood to bring lazy loading and dequeeung into SwiftUI

## Installation

Install using Swift Package Manager.

- File > Swift Packages > Add Package Dependency
- Add https://github.com/sezertunca/LazyHList.git
- Select "Up to Next Major" with "1.0.0"

## Example of usage

```
import SwiftUI

struct Model: Identifiable {
    let id: String
    let imageUrl: String = "https://picsum.photos/200"
}

struct HListViewCell : View {

    let model: Model

    init(model: Model) {
        self.model = model
        debugPrint("🟢 Creating cell: \(model.id)")
    }

    var body: some View {
        AsyncImage(url: URL(string: model.imageUrl))
            .frame(width: 100, height: 100)
            .clipped()
    }
}

struct HListView: View {

    private var items: [Model] {
        return (0...200).map { Model(id: $0.description) }
    }

    var body: some View {
            LazyHList(
                items: self.items,
                itemSize: .fixed(.init(width: 100, height: 100)),
                itemSpacing: .init(mainAxisSpacing: 10, crossAxisSpacing: 30),
                cell: HListViewCell.init)
                .frame(height: 100)
    }
}

struct HListView_Previews: PreviewProvider {

    static var previews: some View {
        HListView()
    }
}
```
