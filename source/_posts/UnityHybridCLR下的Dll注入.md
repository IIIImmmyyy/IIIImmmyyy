---
title: Unity HybridCLR环境下的Dll注入技术详解
date: 2025-07-01 14:30:00
updated: 2025-07-01 14:30:00
tags:
  - Unity
  - HybridCLR
  - 逆向工程
  - Dll注入
  - IL2CPP
categories:
  - 技术分享
  - Unity逆向
description: 深入探讨Unity HybridCLR环境下的Dll注入技术，从基础方案到终极解决方案的完整实践指南
keywords: Unity, HybridCLR, Dll注入, IL2CPP, 逆向工程, 热更新
---

## 📖 引言

### 什么是Unity HybridCLR？

Unity HybridCLR是一个革命性的Unity热更新解决方案。它在高度兼容Unity原生IL2CPP的基础上，实现了一套高性能的解释器来执行C#代码，为Unity开发者提供了完整的C#热更新能力。

---

## 🔍 HybridCLR对逆向工程的影响

### 核心机制变化

由于HybridCLR的引入，Unity应用的编译机制发生了重大变化：

1. **预处理机制**：在编译dll的过程中，HybridCLR会对dll进行预处理，生成大量的占位函数
2. **桥接函数**：这些占位函数是为了桥接到解释器而准备的
3. **地址重用**：这解释了为什么在DumpCS时会看到大量同签名函数指向同一个地址的现象

**典型表现：**
```csharp
// RVA: 0x105CEC4  invoke : 0x105CEC4  VA: 0x7D5BCA1EC4
public bool IsActive(PanelCfg panelCfg) { return false; }

// RVA: 0x1063E34  invoke : 0x1063E34  VA: 0x7D5BCA8E34
public UIBase GetPanel(string componentName) { return null; }
```

### 解释器执行机制

所有占位函数最终都会进入解释器的Execute方法中执行：

```cpp
namespace hybridclr {
    namespace interpreter {
        class Interpreter {
        public:
            static void Execute(const MethodInfo *methodInfo, StackObject *args, void *ret);
        };
    }
}
```

### 逆向工程的挑战

在HybridCLR环境下，传统的Hook方案面临新的挑战：

- **解释器劫持**：需要Hook解释器而非具体函数
- **复杂性增加**：调试和分析难度显著提升
- **方案选择**：需要在多种技术方案中选择最适合的

---

## 🛠️ 解决方案详解

### 方案：利用HybridCLR热更新Dll注入

#### 1. 创建热更新Dll

首先创建一个HybridCLR项目，按照官方文档创建热更dll：

```csharp
public class GameApi
{
    public static async void Init()
    {
        AndroidLogger.LogInfo("GameApi", "GameApi 初始化完成");
    }
}
```

#### 2. 部署热更新Dll

编译完成后，将`HotUpdate.dll`推送到目标设备的沙盒目录：
```bash
/data/data/xxx.xxx.xxx/HotUpdate.dll
```

#### 3. C++注入实现

编写C++代码完成对热更新dll的注入：

```cpp
// 读取热更新dll文件
Unity::Il2CppByteArray *pArray = ReadAllBytes(
    Unity::Il2CppStringProxy::New("/data/data/com.ffcf.lt/files/HotUpdate.dll"));

int arrayLength = Unity::ArrayProxy::Length(pArray);
Unity::AppDomain *domain = Unity::AppDomain::CurrentDomain();

// 加载热更新dll
Unity::Assembly *loadedAssembly = LoadDll(domain, pArray);
Il2CppString *assemblyName = loadedAssembly->GetSimpleName();

// 获取类型和方法
Unity::SystemType *gameApiType = loadedAssembly->GetType(
    Unity::Il2CppStringProxy::New("GameApi"));

if (gameApiType) {
    Unity::SystemMethodInfo *initMethod = gameApiType->GetMethod(
        Unity::Il2CppStringProxy::New("Init"));
    if (initMethod) {
        initMethod->Invoke();
    }
}
```

#### 4. 验证注入结果

运行游戏后，控制台输出：
```
2025-07-01 13:57:12.782  2136-2175  GameApi  com.ffcf.lt  I  GameApi 初始化完成
```

#### 5. 跨域函数调用

成功注入热更新dll后，如何调用热更dll中或非热更dll中的函数？答案是使用反射机制：

```csharp
private static void TestUIManagerAccess()
{
    AndroidLogger.LogInfo("GameApi", "--- 开始测试UIManager访问 ---");

    try
    {
        // 获取类型信息
        var uiManagerType = SmartReflection.FromType("UIManager", "Assembly-CSharp");
        var panelType = SmartReflection.FromType("UIPanelType", "Assembly-CSharp");
        
        // 获取静态成员
        var instance = uiManagerType?.GetValue("Instance");
        var uiBagValue = panelType?.GetValue("UIBag");
      
        // 空值检查
        if (instance == null || uiBagValue == null)
        {
            AndroidLogger.LogError("GameApi", "无法获取必要的对象或值");
            return;
        }
        
        // 包装调用
        var uiManagerWrapper = SmartReflection.FromInstance(instance);
        uiManagerWrapper.Call("ShowPanel", uiBagValue, null, null, false, null);
        
        AndroidLogger.LogInfo("GameApi", "UIManager调用成功");
    }
    catch (Exception ex)
    {
        AndroidLogger.LogError("GameApi", $"UIManager访问测试失败: {ex.Message}", ex);
    }
}
```

#### 方案局限性

虽然反射方案能够实现目标功能，但存在明显的缺陷：

- **性能开销**：反射调用的性能损耗较大
- **开发体验**：代码可读性差，维护困难
- **类型安全**：缺乏编译时类型检查

### 终极解决方案

#### 核心思路

在.NET中，函数调用依赖于签名信息。我们可以构建dll的签名信息，将其依赖到注入dll中，实现与正向开发完全一致的体验。

#### 技术挑战

需要解决以下关键问题：

1. **Unity Dll依赖**：获取Unity编辑器中的dll依赖关系
2. **Assembly-CSharp.dll冲突**：解决如何生成注入dll时的Assembly-CSharp.dll冲突问题
3. **跨域调用**：处理不同程序域之间的调用问题

#### 最终效果

解决上述问题后，代码变得极其简洁和直观：

```csharp
public class GameApi
{
    public static async void Init()
    {
        AndroidLogger.LogInfo("GameApi", "GameApi 开始初始化");

        // 等待游戏完全加载
        await Task.Delay(30000);
        AndroidLogger.LogInfo("GameApi", "GameApi 初始化完成");
        
        // 直接访问游戏对象，如同正向开发
        var uiManager = UnitySingleton<UIManager>.Instance;
        AndroidLogger.LogInfo("GameApi", $"UIManager实例获取成功: {uiManager}");
        
        // 调用游戏方法
        uiManager.ShowPanel(UIPanelType.UIBag);
    }
}
```

#### 动态脚本注入

甚至可以动态添加自定义脚本到游戏对象：

```csharp
// 查找游戏对象并添加自定义脚本
var playerObject = GameObject.Find("Player_shadow");
playerObject.AddComponent<CustomTestScript>();
```

```csharp
public class CustomTestScript : MonoBehaviour
{
    private void Start()
    {
        AndroidLogger.LogDebug("CustomTestScript", "脚本启动成功");
    }
    
    private void Update()
    {
        AndroidLogger.LogDebug("CustomTestScript", "Update方法执行中");
    }
}
```

**执行结果：**
```
2025-07-01 14:08:08.547  2371-2409  CustomTestScript  com.ffcf.lt  D  脚本启动成功
2025-07-01 14:08:08.580  2371-2409  CustomTestScript  com.ffcf.lt  D  Update方法执行中
```

#### 高级应用场景

**脚本热替换：**
```csharp
public class GameApi
{
    public static async void Init()
    {
        AndroidLogger.LogInfo("GameApi", "开始执行脚本替换");
        
        await Task.Delay(30000);
        AndroidLogger.LogInfo("GameApi", "游戏环境准备完成");
        
        var playerObject = GameObject.Find("Player_shadow");
        if (playerObject != null)
        {
            // 移除原有脚本
            UnityEngine.Object.Destroy(playerObject.GetComponent<AIScript>());
            AndroidLogger.LogInfo("GameApi", "原有AIScript已移除");
            
            // 添加自定义脚本（包含从AIScript复制的逻辑）
            playerObject.AddComponent<EnhancedAIScript>();
            AndroidLogger.LogInfo("GameApi", "增强版AI脚本已注入");
        }
    }
}
```

---

## 🔧 相关工具和资源

### Hook支持

对于需要Hook功能的场景，推荐使用：
- **项目地址**：[HybridClrHookNative](https://github.com/IIIImmmyyy/HybridClrHookNative)
- **功能**：提供Native层对CLR Hook的完整支持
- **注意**：由于依赖inline特征，并不能保证每个游戏都兼容

### 替代方案

除了传统Hook外，Dll注入方案还支持：

1. **动态代理Hook**：通过代理模式实现函数拦截
2. **脚本替换**：移除原脚本，注入增强版本
3. **逻辑重写**：完全重写游戏逻辑部分

---

## 💼 商业化解决方案

### 完整解决方案

如果您需要获得在HybridCLR环境下与正向开发完全一致的开发体验，这里提供专业的解决方案：

**方案特点：**
- ✅ 完全兼容HybridCLR环境
- ✅ 与正向开发体验一致
- ✅ 支持完整Unity API调用
- ✅ 提供完整注入、环境部署编译支持；
- ✅ 专业技术支持

**注意事项：**
- 由于方案的技术复杂性和开发成本
- 该解决方案为**付费部署服务**
- 具体费用请联系咨询

---

## 📝 总结

Unity HybridCLR环境下的Dll注入技术为逆向工程师提供了强大的工具，从基础的反射调用到终极的签名依赖解决方案，每种方案都有其适用场景。选择合适的方案需要综合考虑项目复杂度、性能要求和开发成本。

**方案对比：**

| 方案类型   | 开发难度 | 性能表现 | 维护成本 | 适用场景 |
|--------|---------|---------|---------|---------|
| 基础HOOK | 低 | 中 | 低 | 简单功能 |
| 反射调用   | 中 | 低 | 高 | 中等复杂度项目 |
| 终极方案   | 高 | 高 | 低 | 大型项目，追求完美体验 |









