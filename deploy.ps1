#!/usr/bin/env pwsh
# 博客自动部署脚本
# 用法: .\deploy.ps1 "提交消息"

param(
    [Parameter(Mandatory=$false)]
    [string]$CommitMessage = "Update blog content"
)

Write-Host "🚀 开始博客部署流程..." -ForegroundColor Green

# 检查是否在正确的目录
if (!(Test-Path "_config.yml")) {
    Write-Host "❌ 错误：请在博客根目录运行此脚本" -ForegroundColor Red
    exit 1
}

# 步骤1: 清理缓存
Write-Host "🧹 清理Hexo缓存..." -ForegroundColor Yellow
try {
    npx hexo clean
    Write-Host "✅ 缓存清理完成" -ForegroundColor Green
} catch {
    Write-Host "❌ 清理缓存失败: $_" -ForegroundColor Red
    exit 1
}

# 步骤2: 生成静态文件
Write-Host "🔨 生成静态文件..." -ForegroundColor Yellow
try {
    npx hexo generate
    Write-Host "✅ 静态文件生成完成" -ForegroundColor Green
} catch {
    Write-Host "❌ 生成静态文件失败: $_" -ForegroundColor Red
    exit 1
}

# 步骤3: 复制到docs文件夹
Write-Host "📁 复制文件到docs文件夹..." -ForegroundColor Yellow
try {
    # 确保docs文件夹存在
    if (!(Test-Path "docs")) {
        New-Item -ItemType Directory -Name "docs" | Out-Null
    }
    
    # 复制所有文件
    Copy-Item -Path "public\*" -Destination "docs" -Recurse -Force
    Write-Host "✅ 文件复制完成" -ForegroundColor Green
} catch {
    Write-Host "❌ 文件复制失败: $_" -ForegroundColor Red
    exit 1
}

# 步骤4: Git操作
Write-Host "📤 提交并推送到GitHub..." -ForegroundColor Yellow
try {
    # 检查Git状态
    $gitStatus = git status --porcelain
    if ($gitStatus) {
        Write-Host "📝 检测到文件更改，准备提交..." -ForegroundColor Cyan
        
        git add .
        git commit -m $CommitMessage
        
        Write-Host "🚀 推送到远程仓库..." -ForegroundColor Cyan
        git push origin main
        
        Write-Host "✅ 推送完成！" -ForegroundColor Green
    } else {
        Write-Host "ℹ️  没有检测到文件更改，跳过Git操作" -ForegroundColor Blue
    }
} catch {
    Write-Host "❌ Git操作失败: $_" -ForegroundColor Red
    exit 1
}

# 完成
Write-Host ""
Write-Host "🎉 博客部署完成！" -ForegroundColor Green
Write-Host "🌐 请访问: https://iiiimmmyyy.github.io/IIIImmmyyy/" -ForegroundColor Cyan
Write-Host "⏰ GitHub Pages可能需要几分钟时间更新内容" -ForegroundColor Yellow
Write-Host "" 