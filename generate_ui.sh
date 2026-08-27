#!/bin/bash

# ============================================
# 精准版 - 只替换 .slide 结构
# ============================================

# 设置颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# 图片文件夹（默认 ./ui）
IMAGE_DIR="${1:-./ui}"
OUTPUT_FILE="./ui.html"

echo ""
echo -e "${GREEN}🖼️  图片左右切换 HTML 生成器${NC}"
echo ""

# 检查图片文件夹
if [ ! -d "$IMAGE_DIR" ]; then
    echo -e "${RED}❌ 错误: 图片文件夹 '$IMAGE_DIR' 不存在${NC}"
    echo "请创建该文件夹并放入图片"
    exit 1
fi

# 支持的图片格式
IMAGE_EXTS=("jpg" "jpeg" "png" "gif" "webp" "svg" "bmp" "tiff" "heic" "avif" "ico")

# 扫描图片
find_cmd="find \"$IMAGE_DIR\" -maxdepth 1 -type f"
for ext in "${IMAGE_EXTS[@]}"; do
    find_cmd="$find_cmd -iname \"*.$ext\" -o"
done
find_cmd="${find_cmd% -o}"

mapfile -t IMAGE_FILES < <(eval $find_cmd | sort)

if [ ${#IMAGE_FILES[@]} -eq 0 ]; then
    echo -e "${RED}❌ 在 '$IMAGE_DIR' 中没有找到图片${NC}"
    echo "支持的格式: ${IMAGE_EXTS[*]}"
    exit 1
fi

echo -e "${GREEN}✅ 找到 ${#IMAGE_FILES[@]} 张图片${NC}"
echo ""

# 生成 .slide 结构
SLIDE_HTML=""
for i in "${!IMAGE_FILES[@]}"; do
    filename=$(basename "${IMAGE_FILES[$i]}")
    # 转义 HTML 特殊字符（用于 alt 属性）
    escaped=$(echo "$filename" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g')
    
    SLIDE_HTML+="  <!-- 图片 $((i+1)) -->\n"
    SLIDE_HTML+="  <div class=\"slide\" data-index=\"$i\">\n"
    SLIDE_HTML+="    <img src=\"$IMAGE_DIR/$filename\" alt=\"$escaped\" loading=\"lazy\" />\n"
    SLIDE_HTML+="  </div>\n\n"
done

# 如果 ui.html 不存在，提示错误
if [ ! -f "$OUTPUT_FILE" ]; then
    echo -e "${RED}❌ 错误: $OUTPUT_FILE 不存在${NC}"
    echo "请先准备好 ui.html 模板文件"
    exit 1
fi

# 备份原文件
cp "$OUTPUT_FILE" "$OUTPUT_FILE.bak"
echo -e "${YELLOW}📦 已备份: $OUTPUT_FILE.bak${NC}"

# 使用 Python 精确替换
if command -v python3 &> /dev/null; then
    python3 << PYTHON_SCRIPT
import re

with open("$OUTPUT_FILE", "r", encoding="utf-8") as f:
    content = f.read()

# 读取 slide 内容
slide_html = """$SLIDE_HTML"""

# 方法：找到 <!-- 滑动容器 --> 和 <!-- 圆点指示器 --> 之间的内容并替换
pattern = r'(<!-- 滑动容器 -->\s*<div class="slider-wrapper"[^>]*>).*?(</div>\s*<!-- 圆点指示器 -->)'

# 执行替换
def replace_slides(match):
    return match.group(1) + '\n' + slide_html + match.group(2)

content = re.sub(pattern, replace_slides, content, flags=re.DOTALL)

# 如果上面替换失败（没有注释标记），尝试另一种方式
# 查找 <div class="slider-wrapper" id="sliderWrapper"> 到下一个 </div> 之间的内容
if '___SLIDE_HTML___' in content or '<!-- 圆点指示器 -->' not in content:
    pattern2 = r'(<div class="slider-wrapper"[^>]*>).*?(</div>\s*<!-- 圆点指示器 -->)'
    content = re.sub(pattern2, lambda m: m.group(1) + '\n' + slide_html + m.group(2), content, flags=re.DOTALL)

with open("$OUTPUT_FILE", "w", encoding="utf-8") as f:
    f.write(content)

print("✅ 替换完成")
PYTHON_SCRIPT
else
    # 如果 Python 不可用，使用 sed
    echo -e "${YELLOW}⚠️  未找到 Python3，使用 sed 替换${NC}"
    
    # 转义特殊字符
    ESCAPED_SLIDES=$(echo "$SLIDE_HTML" | sed 's/\\/\\\\/g; s/&/\\&/g; s/\//\\\//g; s/"/\\"/g')
    
    # 使用 sed 替换
    sed -i '' "/<!-- 滑动容器 -->/,/<!-- 圆点指示器 -->/c\\
<!-- 滑动容器 -->\\
<div class=\"slider-wrapper\" id=\"sliderWrapper\">\\
$ESCAPED_SLIDES\\
</div>\\
<!-- 圆点指示器 -->" "$OUTPUT_FILE"
fi

echo ""
echo -e "${GREEN}✅ 已更新: $OUTPUT_FILE${NC}"
echo -e "${YELLOW}📊 共 ${#IMAGE_FILES[@]} 张图片${NC}"
echo ""
echo -e "${BLUE}📝 替换的图片:${NC}"
for i in "${!IMAGE_FILES[@]}"; do
    echo -e "   ${BLUE}$((i+1))${NC}. $(basename "${IMAGE_FILES[$i]}")"
done
echo ""
echo -e "${GREEN}🌐 在浏览器中打开:${NC}"
echo -e "   open \"$OUTPUT_FILE\""
echo ""