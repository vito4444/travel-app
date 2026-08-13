# 行程管家 TripKeeper

本仓库含两个端：iOS App（本页说明）与微信小程序版（[WeChatMiniProgram/](WeChatMiniProgram/)，功能界面一致，导入微信开发者工具即可运行）。

一款中文 iOS 旅行规划管理 App：行程时间轴、地图路线一键优化并自动回写行程、订票平台深链跳转（携程/去哪儿/飞猪/12306/美团等）、订票短信离线解析导入、行前清单、预算记账、天气、出发提醒、足迹统计与行程分享。功能设计对标圆周旅迹，并吸收了 TripIt（订单信息组织、出发提醒）、Wanderlog（地图规划、路线优化、预算）、穷游行程助手 / 出发吧（清单、离线数据、行程单导出）的优点。

- 技术栈：SwiftUI + SwiftData + MapKit，最低 iOS 17，全部数据仅存本机，无账号无后端。
- 天气：Open-Meteo 免费接口（无需 key），仅覆盖今天起 16 天内的行程日期。

## 构建与运行

需要 macOS + Xcode 16 或更高版本（工程使用 Xcode 16 的目录同步格式）。本仓库在 Linux 环境编写，未经 Xcode 编译，首次构建如遇问题按报错微调即可。

1. 用 Xcode 打开 `TripKeeper.xcodeproj`。
2. 在 Signing & Capabilities 里选择你的开发者 Team（个人免费账号即可），Bundle Identifier 可改成自己的。
3. 选择 iPhone 模拟器或真机运行。URL Scheme 跳转（唤起携程等 App）只在真机且装有对应 App 时生效，模拟器会回落到网页。

可选：在装有 Swift 工具链的机器上运行 `bash LinuxVerification/run.sh`，可独立验证订票文本解析器与路线优化算法的行为（32 项断言）。

## 功能一览

- 行程管理：新建行程后按起止日期自动生成每日日程；列表显示倒计时/旅行中状态；删除有二次确认。
- 每日时间轴：按天分组，天头部显示日期、星期与天气；条目支持拖拽排序（右上角编辑模式）、左滑删除、点击编辑。
- 行程条目：航班 / 火车 / 酒店 / 景点 / 餐饮 / 交通 / 其他 7 类，表单字段随类型变化；地点通过 MKLocalSearch 搜索并带坐标；可挂照片附件（票据、证件截图）。
- 预订信息与一键跳转：条目可关联平台、订单号、电话、订单链接，卡片上直接出现「打开App / 打开链接 / 打电话 / 复制订单号」按钮；长按条目可跳转高德/百度/苹果地图导航。
- 地图路线规划：每日地图显示带序号的标记与连线；「优化顺序」用最近邻 + 2-opt（固定首尾）重排中间点；相邻条目间用 MKDirections 计算驾车/步行时长（失败时按直线距离估算并标注「估算」）；「应用到行程」把新顺序与推算时间写回，时间轴即时更新。
- 智能导入：粘贴 12306 购票短信、航班/酒店确认短信，本机离线正则解析出车次/航班号、时间、订单号、电话并生成条目，内置三个示例便于体验。
- 行前清单：证件/电子/衣物/洗漱/药品五类模板一键导入，支持勾选与增删，显示完成进度。
- 预算记账：按行程记录花费，分类汇总与总额，配合行程预算显示剩余/超支。
- 出发提醒：对填写了开始时间的航班/火车条目注册本地通知，默认提前 2 小时，可在设置中关闭或调整。
- 足迹统计：旅程数、旅行天数、目的地数，足迹地图撒点显示所有含坐标条目。
- 分享导出：纯文本行程单与 ImageRenderer 生成的行程长图，走系统分享面板。

## 订票平台跳转说明

跳转链为「URL Scheme 唤起 App → 未安装则打开对应网页 → 打开 App Store」。已注册白名单（`TripKeeper/Info.plist` 的 `LSApplicationQueriesSchemes`）：

| 平台 | Scheme | 未安装回落 |
| --- | --- | --- |
| 携程 | `ctrip://` | m.ctrip.com / App Store |
| 去哪儿 | `qunarphone://` | touch.qunar.com / App Store |
| 飞猪 | `taobaotravel://` | m.fliggy.com / App Store |
| 铁路12306 | `cn.12306://` | www.12306.cn |
| 美团 | `imeituan://` | www.meituan.com / App Store |
| 大众点评 | `dianping://` | m.dianping.com |
| 艺龙 | `eltclient://` | m.elong.com |
| 滴滴出行 | `diditaxi://` | www.didiglobal.com |
| 航旅纵横 | `umetrip://` | www.umetrip.com / App Store |
| 高德/百度地图 | `iosamap://` / `baidumap://` | 网页版 |

客观限制：各平台不向第三方开放「直达某笔订单详情页」的公开深链参数，本 App 做到的是一键唤起对应 App（配合一键复制订单号快速查单），以及打开用户自己粘贴的订单分享链接（Universal Link 装了 App 会直接进 App）。

## 已知边界（设计上未包含）

- 多人协作实时编辑（需后端与账号体系）。
- LLM 版「一键抄作业」与 AI 对话规划（需模型 API key；以离线正则解析导入覆盖订票场景）。
- iCloud 同步（需付费开发者账号 entitlement，数据模型未做阻碍该扩展的设计）。
- 航班动态实时提醒（需付费航班数据源；现为本地静态时间提醒）。
- 平台订单 API 对接（携程等不向个人开发者开放）。

## 目录结构

```
TripKeeper.xcodeproj/        Xcode 16 工程（目录同步格式，手写最小 pbxproj）
TripKeeper/
  TripKeeperApp.swift        入口与 ModelContainer
  Info.plist                 scheme 白名单、定位用途描述
  Models/                    SwiftData 模型与枚举
  Services/                  跳转、路线、天气、解析、通知、导出、地理编码
  Views/                     列表/详情/编辑/地图/清单/记账/导入/足迹/分享/设置
  Support/                   扩展与工具函数
LinuxVerification/           解析器与路线算法的独立行为验证（swiftc 直接可跑）
```
