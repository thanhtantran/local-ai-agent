#!/bin/bash
# =========================================================================
#  Orange Pi Local AI Agent - Script Cài Đặt Tự Động
# =========================================================================

# --- Màu sắc ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# --- Hàm tiện ích ---
ok()   { echo -e "${GREEN}  ✓ $1${NC}"; }
warn() { echo -e "${YELLOW}  ⚠ $1${NC}"; }
err()  { echo -e "${RED}  ✗ LỖI: $1${NC}"; }
die()  { err "$1"; echo -e "${RED}Cài đặt thất bại. Vui lòng kiểm tra lỗi bên trên.${NC}"; exit 1; }
step() { echo -e "\n${CYAN}${BOLD}[$1] $2${NC}"; }

# --- Kiểm tra quyền sudo ---
if ! sudo -n true 2>/dev/null; then
    echo -e "${YELLOW}Script cần quyền sudo. Vui lòng nhập mật khẩu nếu được yêu cầu.${NC}"
fi

echo ""
echo -e "${GREEN}${BOLD}=================================================${NC}"
echo -e "${GREEN}${BOLD}   Orange Pi Local AI Agent - Cài Đặt Tự Động   ${NC}"
echo -e "${GREEN}${BOLD}=================================================${NC}"
echo ""

# =========================================================================
# 1. CÀI ĐẶT GÓI HỆ THỐNG
# =========================================================================
step "1/7" "Cài đặt các gói hệ thống (apt)..."

sudo apt update -qq || die "Không thể cập nhật danh sách gói apt."
sudo apt install -y \
    python3-tk python3-venv python3-dev python3-pip \
    libasound2-dev portaudio19-dev \
    liblapack-dev libblas-dev \
    cmake build-essential \
    espeak-ng git wget curl \
    || die "Cài đặt gói apt thất bại."
ok "Các gói hệ thống đã được cài đặt."

# =========================================================================
# 2. TẠO THƯ MỤC
# =========================================================================
step "2/7" "Tạo các thư mục cần thiết..."

mkdir -p piper voices models sounds/greeting_sounds sounds/ack_sounds sounds/thinking_sounds sounds/error_sounds
ok "Thư mục đã sẵn sàng."

# =========================================================================
# 3. TẢI PIPER TTS
# =========================================================================
step "3/7" "Cài đặt Piper TTS..."

ARCH=$(uname -m)
if [ "$ARCH" == "aarch64" ]; then
    if [ -f "piper/piper" ]; then
        warn "Piper đã tồn tại, bỏ qua tải về."
    else
        echo "  Đang tải Piper cho arm64..."
        wget -q --show-progress -O piper.tar.gz \
            https://github.com/thanhtantran/piper-tts-cpu/raw/refs/heads/main/piper_arm64.tar.gz \
            || die "Tải Piper thất bại. Kiểm tra kết nối internet."
        tar -xf piper.tar.gz -C piper --strip-components=1 \
            || die "Giải nén Piper thất bại."
        rm piper.tar.gz
        chmod +x piper/piper
        ok "Piper đã được cài đặt."
    fi
else
    warn "Kiến trúc '$ARCH' không phải aarch64. Bỏ qua tải Piper."
    warn "Vui lòng cài đặt Piper thủ công tại: https://github.com/rhasspy/piper/releases"
fi

# =========================================================================
# 4. TẢI MODEL GIỌNG NÓI
# =========================================================================
step "4/7" "Tải model giọng nói Piper..."

echo ""
echo -e "${CYAN}${BOLD}  ┌─────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}${BOLD}  │          Chọn giọng nói (Piper TTS)                 │${NC}"
echo -e "${CYAN}${BOLD}  ├─────────────────────────────────────────────────────┤${NC}"
echo -e "${CYAN}  │  ${BOLD}1) Deepman${NC}${CYAN}   - Giọng nam trầm ấm                   │${NC}"
echo -e "${CYAN}  │  ${BOLD}2) Ngọc Ngạn${NC}${CYAN} - Giọng Nguyễn Ngọc Ngạn              │${NC}"
echo -e "${CYAN}${BOLD}  └─────────────────────────────────────────────────────┘${NC}"
echo ""

VOICE_CHOICE=""
while true; do
    read -rp "  Nhập lựa chọn của bạn [1/2]: " VOICE_CHOICE
    case "$VOICE_CHOICE" in
        1|2) break ;;
        *) warn "Lựa chọn không hợp lệ. Vui lòng nhập 1 hoặc 2." ;;
    esac
done

cd voices

case "$VOICE_CHOICE" in
    1)
        VOICE_FILES=(
            "deepman.onnx|https://github.com/thanhtantran/piper-tts-cpu/raw/refs/heads/main/models/deepman3909.onnx"
            "deepman.onnx.json|https://github.com/thanhtantran/piper-tts-cpu/raw/refs/heads/main/models/deepman3909.onnx.json"
        )
        VOICE_MODEL_PATH="voices/deepman.onnx"
        VOICE_LABEL="Deepman (giọng nam trầm ấm)"
        ;;
    2)
        VOICE_FILES=(
            "ngocngan.onnx|https://github.com/thanhtantran/piper-tts-cpu/raw/refs/heads/main/models/ngocngan3701.onnx"
            "ngocngan.onnx.json|https://github.com/thanhtantran/piper-tts-cpu/raw/refs/heads/main/models/ngocngan3701.onnx.json"
        )
        VOICE_MODEL_PATH="voices/ngocngan.onnx"
        VOICE_LABEL="Ngọc Ngạn (giọng Nguyễn Ngọc Ngạn)"
        ;;
esac

for FILE_PAIR in "${VOICE_FILES[@]}"; do
    FILENAME="${FILE_PAIR%%|*}"
    URL="${FILE_PAIR##*|}"
    if [ -f "$FILENAME" ]; then
        warn "$FILENAME đã tồn tại, bỏ qua."
    else
        echo "  Đang tải $FILENAME..."
        wget -q --show-progress -O "$FILENAME" "$URL" \
            || die "Tải $FILENAME thất bại. Kiểm tra kết nối internet."
    fi
done

cd ..
ok "Giọng nói đã chọn: $VOICE_LABEL"

# =========================================================================
# 5. CÀI ĐẶT THƯ VIỆN PYTHON
# =========================================================================
step "5/7" "Cài đặt môi trường Python và thư viện..."

# Tạo venv nếu chưa có
if [ ! -d "venv" ]; then
    echo "  Đang tạo môi trường ảo Python..."
    python3 -m venv venv || die "Không thể tạo môi trường ảo Python."
    ok "Môi trường ảo đã được tạo."
else
    warn "Môi trường ảo đã tồn tại, sử dụng lại."
fi

# Kích hoạt venv
source venv/bin/activate || die "Không thể kích hoạt môi trường ảo."

pip install --upgrade pip -q

echo "  Cài đặt lại sounddevice (liên kết với PortAudio mới)..."
pip install --force-reinstall --no-cache-dir sounddevice -q \
    || warn "Cài đặt sounddevice có vấn đề, thử tiếp tục..."

if [ -f "requirements.txt" ]; then
    echo "  Đang cài đặt các thư viện từ requirements.txt..."
    pip install -r requirements.txt -q || die "Cài đặt requirements.txt thất bại."
    ok "Thư viện Python đã được cài đặt."
else
    warn "Không tìm thấy requirements.txt, bỏ qua."
fi

# =========================================================================
# 6. CÀI ĐẶT LITERT-LM VÀ TẢI MODEL AI
# =========================================================================
step "6/7" "Cài đặt LiteRT-LM và tải model Gemma 4..."

# 6a. Cài đặt litert-lm-api + huggingface-hub cùng lúc
echo "  Đang cài đặt litert-lm-api và huggingface-hub..."
pip install litert-lm-api huggingface-hub -q
if [ $? -ne 0 ]; then
    warn "Cài đặt litert-lm-api thất bại. Thử phiên bản nightly..."
    pip install litert-lm-api-nightly huggingface-hub -q \
        || die "Cài đặt litert-lm-api-nightly cũng thất bại. Kiểm tra kết nối internet và phiên bản Python (cần 3.10+)."
fi
ok "litert-lm-api và huggingface-hub đã được cài đặt."

# 6b. Hỏi người dùng chọn model
echo ""
echo -e "${CYAN}${BOLD}  ┌─────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}${BOLD}  │          Chọn Model AI (Gemma 4)                    │${NC}"
echo -e "${CYAN}${BOLD}  ├─────────────────────────────────────────────────────┤${NC}"
echo -e "${CYAN}  │  ${BOLD}1) Gemma 4 E2B${NC}${CYAN} (~2.0 GB RAM) - Nhanh hơn          │${NC}"
echo -e "${CYAN}  │     Phù hợp: Orange Pi 3B RAM trở lên                │${NC}"
echo -e "${CYAN}  │                                                       │${NC}"
echo -e "${CYAN}  │  ${BOLD}2) Gemma 4 E4B${NC}${CYAN} (~3.8 GB RAM) - Thông minh hơn     │${NC}"
echo -e "${CYAN}  │     Phù hợp: Orange Pi 5 / 8B RAM trở lên            │${NC}"
echo -e "${CYAN}  │                                                       │${NC}"
echo -e "${CYAN}  │  ${BOLD}3) Bỏ qua${NC}${CYAN} - Đã có model hoặc tự tải sau           │${NC}"
echo -e "${CYAN}${BOLD}  └─────────────────────────────────────────────────────┘${NC}"
echo ""

MODEL_CHOICE=""
while true; do
    read -rp "  Nhập lựa chọn của bạn [1/2/3]: " MODEL_CHOICE
    case "$MODEL_CHOICE" in
        1|2|3) break ;;
        *) warn "Lựa chọn không hợp lệ. Vui lòng nhập 1, 2 hoặc 3." ;;
    esac
done

# 6c. Hàm tải model dùng lệnh `hf` (huggingface-hub >= 0.27)
download_model() {
    local REPO="$1"
    local FILENAME="$2"
    local DESTDIR="./models"

    echo "  Đang tải $FILENAME từ Hugging Face..."
    hf download "$REPO" "$FILENAME" --local-dir "$DESTDIR" \
        || die "Tải model thất bại. Kiểm tra kết nối internet hoặc tải thủ công tại:\n  https://huggingface.co/$REPO"
    ok "Model $FILENAME đã tải về thành công → $DESTDIR/$FILENAME"
}

case "$MODEL_CHOICE" in
    1)
        echo ""
        echo -e "  ${YELLOW}Đang tải Gemma 4 E2B (~2 GB, có thể mất vài phút)...${NC}"
        download_model \
            "litert-community/gemma-4-E2B-it-litert-lm" \
            "gemma-4-E2B-it.litertlm"

        # Ghi model path vào config.json
        CONFIG_MODEL_PATH="./models/gemma-4-E2B-it.litertlm"
        ;;
    2)
        echo ""
        echo -e "  ${YELLOW}Đang tải Gemma 4 E4B (~3.8 GB, có thể mất vài phút)...${NC}"
        download_model \
            "litert-community/gemma-4-E4B-it-litert-lm" \
            "gemma-4-E4B-it.litertlm"

        CONFIG_MODEL_PATH="./models/gemma-4-E4B-it.litertlm"
        ;;
    3)
        warn "Bỏ qua tải model. Bạn cần tự đặt model vào thư mục ./models/"
        warn "và cập nhật 'text_model' trong config.json."
        CONFIG_MODEL_PATH=""
        ;;
esac

# 6d. Cập nhật config.json với text_model và voice_model đã chọn
if [ -f "config.json" ]; then
    python3 -c "
import json
with open('config.json', 'r') as f:
    cfg = json.load(f)
if '$CONFIG_MODEL_PATH':
    cfg['text_model'] = '$CONFIG_MODEL_PATH'
cfg['voice_model'] = '$VOICE_MODEL_PATH'
cfg.pop('vision_model', None)
with open('config.json', 'w') as f:
    json.dump(cfg, f, indent=4)
print('  config.json đã được cập nhật.')
" || warn "Không thể cập nhật config.json tự động. Vui lòng sửa thủ công."
else
    python3 -c "
import json
cfg = {
    'text_model': '$CONFIG_MODEL_PATH' or './models/gemma-4-E2B-it.litertlm',
    'voice_model': '$VOICE_MODEL_PATH',
    'chat_memory': True,
    'camera_rotation': 0,
    'system_prompt_extras': '',
    'input_device': None,
    'input_sample_rate': None
}
with open('config.json', 'w') as f:
    json.dump(cfg, f, indent=4)
print('  config.json đã được tạo mới.')
" || warn "Không thể tạo config.json."
fi
[ -n "$CONFIG_MODEL_PATH" ] && ok "Cấu hình model AI : $CONFIG_MODEL_PATH"
ok "Cấu hình giọng nói: $VOICE_MODEL_PATH"

# =========================================================================
# 7. TẢI WAKE WORD MODEL
# =========================================================================
step "7/7" "Tải model wake word..."

if [ -f "wakeword.onnx" ]; then
    warn "wakeword.onnx đã tồn tại, bỏ qua tải về."
else
    echo "  Đang tải wake word 'Hi Orange Pi'..."
    WAKEWORD_URL="https://github.com/thanhtantran/piper-tts-cpu/raw/refs/heads/main/wakeword.onnx"
    curl -fL --progress-bar -o wakeword.onnx "$WAKEWORD_URL"
    if [ $? -ne 0 ]; then
        warn "Tải wakeword.onnx thất bại."
        warn "Bạn có thể đặt file wakeword.onnx vào thư mục gốc sau."
        warn "Khi không có wake word, hệ thống sẽ dùng nút nhấn (PTT) thay thế."
    else
        ok "Wake word đã được tải về."
    fi
fi

# =========================================================================
# HOÀN TẤT
# =========================================================================
echo ""
echo -e "${GREEN}${BOLD}=================================================${NC}"
echo -e "${GREEN}${BOLD}   ✨ Cài đặt hoàn tất!                          ${NC}"
echo -e "${GREEN}${BOLD}=================================================${NC}"
echo ""
echo -e "  Để khởi động trợ lý, chạy các lệnh sau:"
echo ""
echo -e "  ${BOLD}source venv/bin/activate${NC}"
echo -e "  ${BOLD}python main.py${NC}"
echo ""

# Kiểm tra nhanh các thành phần quan trọng
echo -e "${CYAN}  Kiểm tra nhanh:${NC}"
[ -f "piper/piper" ]      && ok "Piper TTS"          || warn "Piper chưa có (./piper/piper)"
[ -f "voices/ngocngan.onnx" ] && ok "Giọng ngocngan" || warn "Thiếu voices/ngocngan.onnx"
[ -f "wakeword.onnx" ]    && ok "Wake word"           || warn "Thiếu wakeword.onnx (sẽ dùng PTT)"
[ -f "main.py" ]          && ok "main.py"             || warn "Thiếu main.py"
[ -f "config.json" ]      && ok "config.json"         || warn "Thiếu config.json"
if [ -n "$CONFIG_MODEL_PATH" ] && [ -f "$CONFIG_MODEL_PATH" ]; then
    ok "Model AI: $CONFIG_MODEL_PATH"
elif [ "$MODEL_CHOICE" == "3" ]; then
    warn "Model AI chưa được tải (bỏ qua theo lựa chọn)"
else
    warn "Model AI chưa được tải"
fi
echo ""