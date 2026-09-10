<div align="center">

**한국어** | [English](README.en.md)

<img src="assets/logo.png" width="160" alt="Sound2Haptics 로고 — 트랙패드 냥이">

### **맥북 트랙패드로 느끼는 음악의 박자**

유튜브나 음악을 틀면, 소리의 주파수와 위치에 맞춰 트랙패드가 손가락을 톡톡 쳐 줍니다.  
BlackHole 같은 가상 오디오 드라이버를 깔 필요 없이, 앱 하나만 켜면 바로 작동합니다.

**`swift run Sound2Haptics`**

[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg?logo=swift)](https://swift.org)
[![Platform: macOS 14.0+](https://img.shields.io/badge/Platform-macOS%2014.0%2B-black.svg?logo=apple)](https://www.apple.com/macos/)
[![Hardware: Force Touch Trackpad](https://img.shields.io/badge/Hardware-Force%20Touch%20Trackpad-blue.svg)]()
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Tests: 36/36 Passing](https://img.shields.io/badge/Tests-36%2F36%20passed-brightgreen.svg)]()
[![Driver-Free](https://img.shields.io/badge/Virtual%20Driver-Zero%20(No%20BlackHole)-success.svg)]()

**[실제 동작](#실제-동작) · [왜 만들었는가](#왜-만들었는가) · [동작 원리](#동작-원리) · [설치 및 실행](#설치-및-실행) · [개발 보고서](docs/AI_Software_Lab_Week2_Report.md)**

<br/>

<img src="assets/demo.gif" width="460" alt="Sound2Haptics 실제 실행 애니메이션: 실시간 주파수 반응 및 트랙패드 터치 햅틱">

</div>

---

## 실제 동작

<div align="center">

| macOS 메뉴바 팝오버 UI | 알루미늄 가상 트랙패드 |
|:---:|:---:|
| <img src="assets/ui_preview.png" width="340" alt="Sound2Haptics 메뉴바 팝오버"> | <img src="assets/trackpad_preview.png" width="340" alt="알루미늄 가상 트랙패드"> |
| *음악 주파수 4대역 레벨 바와 동적 상태 뱃지* | *터치한 손가락 위치 추적 및 비트 반응 파동* |

</div>

- **애플 순정 감성의 UI**: 과한 네온이나 사이버펑크 스타일 대신, 맥북 알루미늄 질감과 반투명 블러 효과를 살렸습니다.
- **4대역 주파수 분리**: 서브베이스(20-80Hz), 베이스(80-250Hz), 미드(250-4000Hz), 트레블(4-20kHz) 에너지를 캡슐 모양 게이지로 보여줍니다.
- **실시간 손가락 추적**: 트랙패드에 손가락을 대면 그 위치를 실시간으로 따라가고, 비트가 칠 때마다 하얀 파동 링이 퍼져나갑니다.

---

## 왜 만들었는가

맥북의 포스 터치 트랙패드는 사실 물리적으로 눌리는 버튼이 아닙니다. 유리판 아래에 달린 진동 모터(Taptic Engine)가 손가락을 밀어내서 '클릭된 것 같은 착각'을 일으키는 장치입니다.

노트북 중 가장 정밀한 햅틱 모터가 들어있는데도, 평소에는 파일 클릭할 때 말고는 쓸 일이 없습니다. "음악을 들을 때 손끝으로 진동을 느끼게 만들 순 없을까?" 하는 생각에서 출발했습니다.

기존에 소리를 진동으로 바꿔주는 도구들은 가상 오디오 케이블(BlackHole, Soundflower)을 따로 깔아야 해서 설치가 번거롭거나, 수십만 원짜리 외장 진동 장비를 사야 했습니다. Sound2Haptics는 드라이버 설치 없이 맥북 자체 하드웨어만으로 바로 소리를 만질 수 있게 만듭니다.

### 기존 방식과의 비교

| 구분 | 일반 맥북 기본 상태 | 가상 오디오 드라이버 방식 | 외장 햅틱 장비 | Sound2Haptics |
|---|---|---|---|---|
| **가상 드라이버 설치** | 없음 | BlackHole/Soundflower 필수 | 전용 드라이버 필수 | **설치 필요 없음 (Zero Driver)** |
| **추가 비용** | 0원 | 0원 | 30~50만 원 (진동 조끼 등) | **0원 (맥북 내장 하드웨어)** |
| **오디오 지연 시간** | 없음 | 버퍼 루프백으로 지연 (~50ms) | 블루투스 무선 지연 (>40ms) | **실시간 캡처 (<5ms)** |
| **소리 위치 분리** | 없음 | 좌우 1차원만 가능 | 모터 위치 고정 | **트랙패드 2D 좌표 1:1 매핑** |
| **진동 세기 조절** | 단순 고정 클릭 | 단순 음량 비례 | 프리셋 진동 패턴 | **음량 크기에 따른 3단계 자동 조절** |

---

## 동작 원리

```mermaid
flowchart TD
    A["macOS 시스템 소리<br/>(음악, 유튜브, 게임, 영화)"] -->|드라이버 없이 직접 수신| B["CoreAudio Process Tap<br/>ScreenCaptureKit"]
    B -->|48kHz 오디오 버퍼| C["AudioStreamProcessor"]
    
    subgraph DSP ["Apple Accelerate vDSP (초고속 연산)"]
        C -->|1024-pt FFT| D["AudioDSPAnalyzer"]
        D --> E["4개 주파수 대역 분리<br/>(서브베이스, 베이스, 미드, 트레블)"]
        D --> F["좌우 스테레오 패닝 계산"]
        D --> G["순간 어택 비트 검출"]
    end

    subgraph Hardware ["트랙패드 터치 감지"]
        H["맥북 트랙패드"] -->|프라이빗 C ABI| I["MultitouchTracker"]
        I -->|손가락 좌표 (x, y)| J["SpatialTouchGate"]
    end

    E & F & G --> K["동적 진동 강도 판정기"]
    K -->|Light / Medium / Strong 결정| L["HapticEngine"]
    
    J -->|터치 위치와 소리 대역 일치 확인| L
    L -->|최소 쿨다운 보장| M["MultitouchActuator"]
    M -->|트랙패드 클릭!| N["MacBook Taptic Engine"]
```

1. **소리 가로채기**: macOS 최신 기능(CoreAudio Process Tap)으로 가상 오디오 케이블 없이 시스템 소리를 지연 없이 바로 가져옵니다.
2. **주파수 쪼개기**: Apple Accelerate 라이브러리로 1024개 샘플을 0.1ms 만에 주파수별로 쪼개어, 쿵쿵거리는 베이스와 찰랑거리는 고음을 나눕니다.
3. **손가락 위치 찾기**: 트랙패드 프레임워크의 메모리 구조를 역공학해, 손가락이 트랙패드 어느 위치(X, Y)에 닿아 있는지 오차 없이 읽어옵니다.
4. **햅틱 출력**: 소리가 나는 위치와 손가락 위치가 맞을 때만, 소리의 크기에 맞춰 3단계(약함, 중간, 강함)로 트랙패드를 톡톡 쳐 줍니다.

---

## 공간 및 주파수 매핑

트랙패드를 2차원 공간 악기처럼 쓸 수 있습니다:

```
┌──────────────────────────────────────────────┐
│  고음역 / Treble (심벌즈, 하이햇, 보컬 고역)  │  (상단 1/3)
├──────────────────────────────────────────────┤
│  중음역 / Mid-Range (보컬, 기타, 피아노, 스네어)│ (중간 1/3)
├──────────────────────────────────────────────┤
│  저음역 / Bass (드럼 킥, 808 베이스, 폭발음)   │  (하단 1/3)
└──────────────────────────────────────────────┘
  왼쪽 소리 (X: 0.0 ~ 0.5)      오른쪽 소리 (X: 0.5 ~ 1.0)
```

- **좌우 소리 분리**: 왼쪽에서만 나는 소리는 트랙패드 왼쪽에 손가락을 얹었을 때만 진동이 옵니다.
- **여러 손가락 터치**: 왼손으로 하단(베이스)을 짚고 오른손으로 상단(하이햇)을 짚으면, 두 악기가 연주될 때 양 손가락에 각각 다른 박자의 진동이 전달됩니다.
- **음량에 따른 자동 강도**: 조용한 부분에서는 살짝 톡 치는 부드러운 탭틱(`Light`), 묵직한 킥이나 비트 드롭에서는 강하게 튕기는 포스터치(`Strong`)로 자동 전환됩니다.

---

## 설치 및 실행

### 준비물
- macOS Sonoma (14.0) 이상이 설치된 맥북
- Force Touch 트랙패드가 탑재된 맥북 (Apple Silicon M1/M2/M3/M4 또는 Intel)
- Xcode Command Line Tools (`xcode-select --install`)

### 실행 방법

터미널을 열고 아래 세 줄만 입력하면 됩니다:

```bash
git clone https://github.com/leeyunseokarchive/Sound2Haptics.git
cd Sound2Haptics
swift run Sound2Haptics
```

실행하면 상단 메뉴바에 파형 아이콘이 나타납니다. 아이콘을 누르면 컨트롤 창이 열립니다.

### 터미널 테스트 명령어

화면을 띄우지 않고 터미널에서 기능만 따로 시험해볼 수도 있습니다:

```bash
# 트랙패드가 제대로 튕기는지 하드웨어 클릭 시험
swift run Sound2Haptics --test-actuator

# 합성 킥 드럼 소리로 주파수 분석과 햅틱 동작 시뮬레이션
swift run Sound2Haptics --demo-dsp

# 3초간 실제 스피커 소리를 받아서 분석해보기
swift run Sound2Haptics --test-capture

# 리드미용 이미지와 데모 GIF 새로 만들기
swift run Sound2Haptics --export-assets
```

---

## 검증 및 테스트

핵심 로직과 하드웨어 브리지 코드는 단위 테스트(TDD)로 작성되어 있습니다.

```bash
$ swift test
Test Suite 'All tests' passed at 2026-09-11 02:27:42.
	 Executed 36 tests, with 0 failures (0 unexpected) in 0.026 seconds
```

36개 테스트 모두 0.026초 만에 통과하며, 트랙패드 C ABI 메모리 정렬부터 주파수 분리 및 터치 게이팅까지 안정성을 검증했습니다. 자세한 문제 해결 과정과 분석 기록은 [개발 및 문제 해결 보고서](docs/AI_Software_Lab_Week2_Report.md)에서 확인하실 수 있습니다.

---

## 프로젝트 구조

```text
Sound2Haptics/
├── Package.swift                             # 패키지 설정
├── README.md                                 # 한국어 설명서
├── README.en.md                              # 영문 설명서
├── assets/                                   # 로고, 시연 GIF, 캡처 이미지
│   ├── logo.png                              # 트랙패드 냥이 공식 로고
│   ├── demo.gif                              # 동작 시연 애니메이션
│   ├── ui_preview.png                        # 메뉴바 팝오버 UI 캡처
│   └── trackpad_preview.png                  # 가상 트랙패드 상세 캡처
├── docs/
│   └── AI_Software_Lab_Week2_Report.md       # 10대 핵심 이슈 해결 보고서
├── Sources/
│   ├── Sound2HapticsCore/                    # 코어 엔진 라이브러리
│   │   ├── Audio/                            # 오디오 버퍼 처리기
│   │   ├── DSP/                              # vDSP FFT 주파수 분석기
│   │   ├── Haptics/                          # 햅틱 엔진 및 터치 매칭 판정
│   │   ├── Models/                           # 설정값 및 햅틱 패턴 모델
│   │   └── Multitouch/                       # 트랙패드 C ABI 브리지
│   └── Sound2Haptics/                        # 메뉴바 실행 앱
│       ├── AppDelegate.swift                 # 메뉴바 아이콘 및 창 관리
│       ├── Audio/                            # ScreenCaptureKit 오디오 소스
│       ├── ViewModels/                       # 뷰모델
│       ├── Views/                            # 메뉴바 UI 및 트랙패드 뷰
│       └── main.swift                        # 실행 진입점 및 CLI 플래그
└── Tests/
    └── Sound2HapticsCoreTests/               # 36개 단위 테스트
```

---

## 라이선스

이 프로젝트는 [MIT 라이선스](LICENSE)를 따릅니다. 누구나 자유롭게 사용하고 기여할 수 있습니다.
