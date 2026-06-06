import Foundation
import Testing
@testable import DomainKit

@Test func decodesProductionRuntimeState() throws {
    let json = """
    {
      "maintenance": {
        "enabled": false,
        "config": {
          "message": "正在进行数据迁移与系统性能优化",
          "eta": "2026年6月6日8点",
          "progress": [
            {
              "id": "step-1",
              "label": "合并 tongji.icu 点评数据",
              "done": true,
              "active": false
            }
          ],
          "lastUpdated": "2026-06-06 03:49:53"
        }
      },
      "announcements": [
        {
          "id": "1780584044996-9qkfvx",
          "type": "success",
          "content": "YourTJ已完成乌龙茶数据合并，等待课表更新中。",
          "enabled": true
        }
      ],
      "updatedAt": 1780718908689
    }
    """

    let state = try JSONDecoder().decode(RuntimeState.self, from: Data(json.utf8))

    #expect(state.maintenance.enabled == false)
    #expect(state.maintenance.config?.message == "正在进行数据迁移与系统性能优化")
    #expect(state.maintenance.config?.estimatedDowntime == "2026年6月6日8点")
    #expect(state.maintenance.config?.progress.first?.label == "合并 tongji.icu 点评数据")
    #expect(state.announcements.first?.title == "更新")
    #expect(state.announcements.first?.content == "YourTJ已完成乌龙茶数据合并，等待课表更新中。")
    #expect(state.updatedAt == 1780718908689)
}
