class_name GameConst
## 조정이 잦은 상수는 여기에 모은다.

# 판정
const PERFECT_MS := 35.0
const GREAT_MS := 70.0
const GREAT_WEIGHT := 0.7           # 점수 비율 (PERFECT = 1.0)
const MAX_SCORE := 1000000

# 구조
# Flick
const FLICK_WINDOW_MS := 130.0      # 노트 시각 +-이 안에서 통과해야 성공 (PERFECT_MS 이내면 PERFECT, 나머지 GREAT)
const FLICK_MIN_SPEED := 1.0        # 최소 커서 속도 (0~1 단위/초). 미세한 흔들림 무시용

const FLICK_X_MARGIN := 0.04         # 통과선 좌우 여유 (0~1 단위). 선 근처까지만 가도 인정

const LANE_COUNT := 4
const TICK_BEAT_FRACTION := 0.125   # Field/Hold tick 간격 (1/8박)

# 3D 하이웨이 (단위: m)
const LANE_WIDTH := 1.1
const SCROLL_UNITS_PER_SEC := 16.0  # hispeed 1.0 기준 노트 속도
const VIEW_DEPTH := 34.0            # 판정선에서 화면 안쪽으로 보이는 거리
const AIR_Y := 1.5                  # 공중 Field 평면 높이
const AIR_Z := 1.0                  # 공중 판정선의 Z (바닥 판정선보다 카메라 쪽으로 당김). 공중 노트도 같이 이동
const FIELD_WIDTH := 4.4            # 공중 Field 가로 폭 (커서 0~1에 대응)
