@echo off
:: 博客自动部署脚本 (批处理版本)
:: 用法: deploy.bat [提交消息]

set "COMMIT_MESSAGE=%~1"
if "%COMMIT_MESSAGE%"=="" set "COMMIT_MESSAGE=Update blog content"

echo 🚀 开始博客部署流程...

:: 检查是否在正确的目录
if not exist "_config.yml" (
    echo ❌ 错误：请在博客根目录运行此脚本
    pause
    exit /b 1
)

:: 步骤1: 清理缓存
echo 🧹 清理Hexo缓存...
call npx hexo clean
if errorlevel 1 (
    echo ❌ 清理缓存失败
    pause
    exit /b 1
)
echo ✅ 缓存清理完成

:: 步骤2: 生成静态文件
echo 🔨 生成静态文件...
call npx hexo generate
if errorlevel 1 (
    echo ❌ 生成静态文件失败
    pause
    exit /b 1
)
echo ✅ 静态文件生成完成

:: 步骤3: 复制到docs文件夹
echo 📁 复制文件到docs文件夹...
if not exist "docs" mkdir docs
xcopy /E /I /Y "public\*" "docs\"
if errorlevel 1 (
    echo ❌ 文件复制失败
    pause
    exit /b 1
)
echo ✅ 文件复制完成

:: 步骤4: Git操作
echo 📤 提交并推送到GitHub...
git add .
git commit -m "%COMMIT_MESSAGE%"
git push origin main
if errorlevel 1 (
    echo ❌ Git操作可能失败，请检查网络连接
    pause
    exit /b 1
)
echo ✅ 推送完成！

:: 完成
echo.
echo 🎉 博客部署完成！
echo 🌐 请访问: https://iiiimmmyyy.github.io/IIIImmmyyy/
echo ⏰ GitHub Pages可能需要几分钟时间更新内容
echo.
pause 