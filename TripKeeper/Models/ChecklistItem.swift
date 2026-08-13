import Foundation
import SwiftData

@Model
final class ChecklistItem {
    var title: String = ""
    var category: String = "其他"
    var isDone: Bool = false
    var sortIndex: Int = 0
    var trip: Trip?

    init(title: String, category: String, sortIndex: Int = 0) {
        self.title = title
        self.category = category
        self.sortIndex = sortIndex
    }
}

/// 行前清单内置模板。
struct ChecklistTemplateGroup {
    let category: String
    let titles: [String]
}

enum ChecklistTemplate {
    static let categories = ["证件", "电子", "衣物", "洗漱", "药品", "其他"]

    static let items: [ChecklistTemplateGroup] = [
        ChecklistTemplateGroup(category: "证件", titles: ["身份证", "护照/签证", "学生证/优惠证件", "行程单打印件", "现金与银行卡"]),
        ChecklistTemplateGroup(category: "电子", titles: ["手机充电器", "充电宝", "耳机", "相机与存储卡", "转换插头"]),
        ChecklistTemplateGroup(category: "衣物", titles: ["换洗衣物", "外套", "舒适步行鞋", "帽子/墨镜", "雨伞/雨衣"]),
        ChecklistTemplateGroup(category: "洗漱", titles: ["牙刷牙膏", "洗面奶", "防晒霜", "护肤品", "毛巾"]),
        ChecklistTemplateGroup(category: "药品", titles: ["感冒药", "肠胃药", "创可贴", "晕车药", "个人常用药"])
    ]
}
