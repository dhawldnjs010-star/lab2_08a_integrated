# 실험 전 레포트: LAB2-08A 8모드 버튼·LCD 통합

작성자: 상혁 (2025440084) / 작성일: 2026-09-21 / 소스 커밋: `__HASH__` / workspace: `LAB1.code-workspace` (템플릿 v2.0.1) / OS: `Windows 11 Home 10.0.26200` / Python: `Python 3.14.7` / 시뮬레이터: Icarus Verilog `12.0 (devel) (s20150603-1539-g2693dd32b)`

## 1. 목적과 예상 동작

LAB2 01–08에서 만든 여덟 순차회로를 하나의 프로젝트(`lab2_integrated`)로 묶어 **bit 하나**로 실행한다. 모드는 N8로 바꾸고 선택한 회로는 N4로 한 단계씩 실행한다. 16×2 LCD는 현재 모드의 번호와 이름을 표시한다. 여덟 코어는 모두 인스턴스화되어 있고, 모드를 바꿀 때 bit를 다시 기록하지 않는다.

| 입력 | 역할 |
|---|---|
| B6 / `clk` | 1 kHz 주 클록 |
| K4 / `rst` | 전체 초기화, 첫 모드(MODE 01)로 복귀 |
| N8 / `mode_button` | 다음 모드 선택 |
| N4 / `step_button` | 선택한 회로 한 단계 실행 (개별 교안의 N8이 통합판에서 N4로 바뀜) |
| SW1–SW8 | `sw[7]`–`sw[0]`, 모드별 입력 |

**내부 번호와 LCD 번호.** 내부 `mode`는 3비트로 0부터 시작하고, LCD에는 1부터 시작하는 번호가 표시된다. 두 번호를 구분해 쓴다.

| 내부 mode | LCD 첫 줄 | LCD 둘째 줄 | LED[7:0] |
|---|---|---|---|
| 0 | MODE 01 | UP DOWN COUNTER | `0000, count` |
| 1 | MODE 02 | CLOCK DIVIDER | `000, tick, /1000, /50, /10, /2` |
| 2 | MODE 03 | REGISTER PAIR | `stored, registered` |
| 3 | MODE 04 | SHIFT REGISTER | `0000, shifted` |
| 4 | MODE 05 | PISO | `parallel, 000, serial_out` |
| 5 | MODE 06 | MOORE FSM | `000000, moore_value` |
| 6 | MODE 07 | MEALY FSM | `00000, mealy_state, mealy_value` |
| 7 | MODE 08 | 8 DIGIT SCAN | `00000, scan_index` |

**모드 변경 규칙.** `circuit_reset = reset || mode_press`이므로 모드 변경 펄스가 들어온 에지에서 여덟 코어가 초기화되고 `mode`가 다음 값으로 바뀐다. 같은 에지에 `step_press`가 함께 1이어도 코어의 reset이 우선한다. 카운터를 15로 만든 뒤 여덟 모드를 돌아 MODE 01에 오면 0이다. MODE 08에서 N8을 한 번 누르면 MODE 01로 돌아온다(3비트 `mode`의 순환).

**표시 장치.** MODE 08 외에는 `seg_data=00`, `seg_com=FF`로 7세그먼트를 끈다. MODE 08은 자동으로 스캔한다(`enable = mode==7`).

**예상 동작 요약(TB 입력 기준).**

| 모드 | 입력 | 예상 LED |
|---|---|---|
| 01 카운터 | `sw[0]=0`에서 N4 → `sw[0]=1`에서 N4 두 번 | `01` → `00` → `0F` (0에서 15로 순환) |
| 02 분주 | TB는 DIVISOR=10 | 30클록에 tick 3번 |
| 03 레지스터 | `A1` N4 → `33` N4 → N4 | `A0` → `3A`(동시 저장·전달은 이전 값) → `33` |
| 04 시프트 | `80` N4 → `00` N4 | `08` → `04` |
| 05 PISO | `A1` N4(load) → `A0` N4 두 번 | `A1` → `40` → `81` |
| 06 Moore | `80`만 바꿈 → N4 세 번 | `00`(입력만으로는 유지) → `01` → `02` → `00` |
| 07 Mealy | `00` → `80`(N4 없이) → N4 → `00` | `00` → `02`(버튼 없이 출력 변화) → `05` → `04` |
| 08 스캔 | `sw[7:4]=9`, 64클록 | 활성 32 + blank 32, index마다 COM 극성·패턴 확인 |

## 2. 소스와 테스트벤치

### 2.1 파일 구성 (RTL 12개, TB 1개, XDC 1개)

| 역할 | 파일 | 설명 |
|---|---|---|
| src | `counter4.v`, `clock_divider.v`, `register_pair.v`, `shift_register4.v`, `piso4.v`, `moore_cycle.v`, `mealy_toggle.v`, `segment_scan8.v` | LAB2 01–08의 코어. 그대로 재사용 |
| src | `input_frontend.v` | 리셋 해제 2단 동기, 모드 버튼·스위치 2단 동기, 20클록 안정 확인, 한 클록 `press`(모드 버튼용) |
| src | `button_onepulse.v` | 한 단계 버튼(N4) 전용 동기·안정 확인·한 클록 펄스 |
| src | `lcd_lab2_modes.v` | 16×2 LCD 쓰기 전용 컨트롤러(초기화 명령, 첫 줄 `MODE 0n`, 둘째 줄 이름) |
| src | `lab2_integrated.v` | 최상위. 여덟 코어와 프런트엔드, LED·7세그먼트·LCD 연결 |
| sim | `tb_lab2_integrated.sv` | 통합 자기검사 TB |
| constraints | `lab2_integrated.xdc` | 핀·1 kHz 클록·false path |
| 설정 | `simulation.json` | `sources` 12개, `testbench`, `simulation_top` |

### 2.2 역할 설명

- **`lab2_integrated.v`**: `STABLE_CYCLES=20`, `DIVISOR=1000`, `LCD_POWER_WAIT=50`이 보드 기본값이다. `mode`(3비트)는 `mode_press`마다 1 증가한다. 각 코어의 enable은 `step_press && mode==k`이고 스캔만 `mode==7`에서 자동으로 동작한다. 분주기는 항상 주 클록으로 동작하며 MODE 02에서 LED로 관찰한다. `led`는 `mode`에 따라 선택하고 `seg_com`은 active-low(`~{selected[0..7]}`)이다.
- **`input_frontend.v` / `button_onepulse.v`**: 비동기 입력을 두 단 레지스터(`ASYNC_REG`)로 받은 뒤, 값이 `STABLE_CYCLES`클록 동안 유지될 때만 한 클록 펄스를 만든다. 스위치는 먼저 정하고 버튼을 누른다.
- **`lcd_lab2_modes.v`**: 한 바이트를 네 단계(0: E=0에서 RS·DATA 준비, 1: E=1, 2: E=0으로 내려 전송, 3: 회복)로 보낸다. `lcd_rw=0`(쓰기 전용). 첫 줄 주소 `80`을 보낼 때 `mode`를 `shown_mode`에 저장하므로 한 화면을 쓰는 동안 번호와 이름이 서로 다른 모드에서 오지 않는다.
- **`tb_lab2_integrated.sv`**: 클록 10 ns. `STABLE_CYCLES=3`, `DIVISOR=10`으로 버튼·분주 대기를 줄인다(LCD 바이트 타이밍은 기본 클록 수 유지). 실제 `lcd_data`·`lcd_rs`·`lcd_e` 버스를 감시해 32칸 `screen`을 만들고, E가 높은 동안 데이터·RS가 바뀌면 `$fatal`로 실패한다. 버튼 입력에는 짧은 바운스와 긴 누름을 넣고 `next_mode`가 한 동작에 모드가 정확히 한 번만 바뀌는지 검사한다. 마지막에 두 버튼 동시 누름과 실행 중 리셋을 검사한다.
- **XDC**: 47개 포트(`clk`, `rst`, `mode_button`, `step_button`, `sw[7:0]`, `led[7:0]`, `seg_data[7:0]`, `seg_com[7:0]`, `lcd_data[7:0]`, `lcd_e`, `lcd_rs`, `lcd_rw`)를 모두 LVCMOS33으로 지정하고, `create_clock`으로 `clk`를 1 kHz(`-period 1000000.000` ns)로, `rst`·버튼·스위치에는 `set_false_path`를 둔다.
- **`simulation.json`**: Icarus 실행 목록. 새 RTL은 이 파일에도 등록해야 하며 module 이름에는 확장자를 붙이지 않는다.

### 2.3 핀 표

| 신호 | 핀 |
|---|---|
| `clk` / `rst` | B6 / K4 |
| `mode_button` / `step_button` | N8 / N4 |
| `sw[0]`…`sw[7]` | U4, V4, W1, W4, T1, U2, W3, Y1 |
| `led[0]`…`led[7]` | N5, M1, M3, M7, N7, M2, M4, L4 |
| `seg_data[0]`…`[7]` | H2, J7, J3, J1, E4, E2, F5, F1 |
| `seg_com[0]`…`[7]` | K5, K3, K1, L6, G3, G1, H6, H4 (활성 자리 출력 0) |
| `lcd_data[0]`…`[7]` | A4, B2, C3, D4, A2, C5, C1, D1 |
| `lcd_e` / `lcd_rs` / `lcd_rw` | A6 / G6 / D6 |

### 2.4 검사 대상 (TB)

| 모드 | 통합 검사 |
|---|---|
| 01 | 증가, 감소, 0에서 15로 순환 |
| 02 | 30클록에 tick 3개(TB /10) |
| 03 | 동시 저장·전달 시 이전 값 |
| 04 | 입력 1, 0에 LED 08, 04 |
| 05 | 병렬 load와 MSB 직렬 출력 |
| 06 | 입력만 바꿔서는 상태 유지 |
| 07 | 버튼 없이 입력으로 출력 변경 |
| 08 | COM 극성, 입력 9, blank 비율 |

## 3. VS Code 실행 과정

- 실행: `Terminal → Run Task → 02 Simulate` (또는 `tools/run_evidence.ps1`이 정상·변경·복구를 한 번에 실행). 정상 기준 로그는 `LAB2_INTEGRATED_PASS modes=8 checks=2848`, 종료 34326 ns(`$finish called at 34326000 (1ps)`, ps 단위)다.
- 로그·VCD: [normal.log](../../evidence/pre/lab2_integrated_normal.log), [wave_normal.vcd](../../evidence/pre/lab2_integrated_wave_normal.vcd)
- 파형 캡처(VaporView, 목적별 5개와 전체): `evidence/pre/lab2_integrated_wave_full.png`(전체 Zoom Fit, 34.326 μs), `_wave_ctrl.png`(제어), `_wave_circuit.png`(회로), `_wave_lcd.png`(LCD MODE 05 전송), `_wave_scan.png`(스캔), `_wave_final.png`(마지막 동시 버튼과 리셋)

### 3.1 사전 파형 해석 (예상 = VCD 값)

시각은 ns이며 TB 클록 에지는 5, 15, 25, … ns이다. 내부 mode를 기준으로 쓰고 LCD 번호는 mode+1이다.

| 시각 | 입력 | 예상 | 해석 |
|---|---|---|---|
| 6 | `rst=1`(2–26 ns) | `mode=0`, `led=00`, `circuit_reset=1` | 리셋 중에는 첫 모드, 출력 0 |
| 205 | `sw=00`, N4 누름(`step_press` 195 ns) | `led=01` | mode 0: 증가 1회 |
| 485 | `sw=01`, N4(`step_press` 475 ns) | `led=00` | 감소 |
| 725 | N4(`step_press` 715 ns) | `led=0F` | 경계: 0에서 15로 순환 |
| 3955 → 3965 | N8(`mode_press` 3955 ns) | 3965 ns: `mode 0→1`, `led 0F→00` | 모드 변경 에지에서 코어 초기화. 이전 카운터 값을 넘기지 않음 |
| 4055 | mode 1, TB DIVISOR=10 | `led=1B`(tick, divided, /10, /2 = 1) | tick이 100 ns마다 1클록 폭. 30클록에 3번 |
| 7785 | mode 2, `sw=A1`, N4(7775 ns) | `led=A0` | load: stored=A, registered 유지 |
| 8065 | `sw=33`, N4(8055 ns) | `led=3A` | 동시 저장·전달: registered는 이전 stored(A), stored는 새 입력 3 |
| 8305 | N4(8295 ns) | `led=33` | 다음 에지에서 registered가 새 stored 3 |
| 11825 | mode 3, `sw=80`, N4(11815 ns) | `led=08` | 직렬 입력 1이 bit 3으로 |
| 12105 | `sw=00`, N4(12095 ns) | `led=04` | 한 칸 이동 |
| 15625 | mode 4, `sw=A1`, N4(15615 ns) | `led=A1` | 병렬 load A, serial_out=MSB=1 |
| 15905 | `sw=A0`, N4(15895 ns) | `led=40` | 왼쪽 shift, 다음 비트 0 |
| 16145 | N4(16135 ns) | `led=81` | 둘째 shift, serial_out=1 |
| 19665 | mode 5, `sw=80`(N4 전 `led=00`) → N4(19655 ns) | `led=01` | 입력만으로는 유지, step에서 S0→S1 |
| 19905 / 20145 | N4 두 번 | `led=02` / `led=00` | S1→S2→S0 순환 |
| 23545 | mode 6, `sw=00` | `led=00` | Mealy: 입력 0이면 출력 00 |
| 23585 | `sw=80`(N4 없이) | `led=02` | 에지가 없어도 입력에 따라 출력이 바뀜(스위치 동기화 2클록 뒤) |
| 23705 | N4(23695 ns) | `led=05` | 상태 S1, 출력 01 |
| 23865 | `sw=00` | `led=04` | S1에서 입력 0이면 출력 00, 상태 유지 |
| 27200 / 27300 | mode 7(26985 ns 진입), `sw[7:4]=9`(27126 ns) | `seg_com=DF`, `seg_data=DA`, `led=02` / `seg_com=FE`, `seg_data=E0`, `led=07` | active-low COM(index 2, 7)과 숫자 2, 7의 세그먼트 패턴 |
| 30156–30786 | 64클록 표본(`check_lcd` 300클록 뒤) | 활성 32 + blank 32 | 슬롯마다 blank 구간이 끼어 `seg_com=FF`가 절반 |
| 30905 | N8(30895 ns) | `mode 7→0`, `led=00` | MODE 08에서 한 번 더 누르면 MODE 01. 이전 카운터 초기화 |
| 34095 → 34105 | N8과 N4 동시 | `mode=1`, `count=0` | 코어 갱신보다 초기화가 우선 |
| 34286 → 34326 | `rst=1` | `mode=0`, `led=00`, `lcd_e=0`, `seg_com=FF` | 실행 중 리셋 |

**LCD MODE 05 전송 구간(약 17.1 μs).** `lcd_data=80`(RS=0)은 첫 줄 주소 명령이고, 이어서 `4D 4F 44 45 20 30 35`(RS=1)가 `MODE 05`, 뒤에서 `C0`(RS=0) 후 `50 49 53 4F ...`가 `PISO`다. 내부 `mode=4`가 LCD 번호 05에 대응한다. `lcd_e`는 데이터가 바뀐 뒤 다음 클록에 올라가고 그다음 클록에 내려가며, E가 높은 동안 `lcd_data`·`lcd_rs`는 유지된다. `lcd_rw`는 항상 0이다.

**시간 해석 주의.** TB는 10 ns 주기와 `STABLE_CYCLES=3`, `DIVISOR=10`으로 줄였다. 보드의 1 kHz 클록에서는 한 클록이 1 ms이고 `STABLE_CYCLES=20`(약 20 ms)이므로 파형의 ns 값을 장비 동작 시간으로 그대로 쓰지 않는다. LCD는 한 화면을 쓰기 시작할 때 모드를 저장하므로, 버튼 직후 화면이 즉시 바뀌는 것이 아니라 다음 화면 갱신에서 반영된다.

## 4. 코드 수정·실패·복구 실험

수정 대상: `src/counter4.v` 10행. 증가량을 1에서 2로 바꾸고 TB 기대값은 유지한다.

```diff
-            else value <= value + 4'd1;
+            else value <= value + 4'd2;
```

실행 전 계산: 첫 N4(`step_press` 195 ns)에서 카운터는 0에서 1이 되어 `led=01`이어야 하지만 변경 회로는 0+2=2가 된다. TB는 이 동작 직후(346 ns)에 `led===1`을 검사하므로 첫 검사 `counter increments once`에서 실패한다.

| 단계 | 소스 커밋 또는 해시 | 실행 폴더·로그 링크 | 입력·기대값·실제값 | 해석 |
|---|---|---|---|---|
| 정상 코드 | `__HASH__` | [normal.log](../../evidence/pre/lab2_integrated_normal.log) | `LAB2_INTEGRATED_PASS modes=8 checks=2848`, `$finish called at 34326000 (1ps)` | 모든 검사 통과, 34326 ns 종료 |
| 지정한 RTL 변경 | 미커밋 수정본(`__HASH__` 기준, 로컬 실행) | [mod.log](../../evidence/pre/lab2_integrated_mod.log) | 346 ns 기대 `led=01`, 실제 `led=02`. `LAB2_INTEGRATED_FAIL counter increments once time=346000`, `FATAL: sim/tb_lab2_integrated.sv:23: check failed` | 첫 카운터 검사가 변경을 발견(로그의 time은 ps, 346000 ps = 346 ns) |
| 원래 코드로 복구 | `__HASH__` | [recover.log](../../evidence/pre/lab2_integrated_recover.log) | 복구 후 전체 검사 재실행. `LAB2_INTEGRATED_PASS modes=8 checks=2848`, `$finish called at 34326000 (1ps)` | PASS와 종료 시각이 정상 실행과 같음 |

## 5. 보드 실험 계획 (Vivado)

### 5.1 장비와 등록 정보

- 클록: 주 클록 B6, 1 kHz(`create_clock -period 1000000.000`). 비동기 입력은 `set_false_path`.
- 부품: `xc7s75fgga484-1`(Spartan-7, -1IL·-1Q와 구분). I/O 표준은 전 포트 LVCMOS33.
- 프로젝트: 이름 `lab2_integrated`, 위치 `프로젝트 폴더/vivado`, RTL Project(소스 없이 시작). 설계 Top `lab2_integrated`, 시뮬레이션 Top `tb_lab2_integrated`.
- 소스 등록: 12개 RTL(빈 `design.v` 제외), `sim/tb_lab2_integrated.sv`, `constraints/lab2_integrated.xdc`. 모두 Copy sources 해제.
- 확인 순서: Run Behavioral Simulation을 **Run All(F3)** 로 `$finish`까지 실행(기본 1000 ns에서는 checks=37에서 멈춤). XSim 기대: `modes=8 checks=2848`, 34326 ns. Elaborated Design I/O Planning에서 All ports 47개와 핀·LVCMOS33을 XDC와 대조. 이어서 Run Synthesis → Run Implementation → Generate Bitstream, 생성 파일은 `vivado/lab2_integrated.runs/impl_1/lab2_integrated.bit`.
- 타이밍: Design Timing Summary의 Setup·Hold slack과 실패 endpoint 수를 확인한다. 교안 기준값은 WNS=999994.312 ns, WHS=0.122 ns, 실패 endpoint 0이다(내 결과와 비교해 기록).
- 경고: `TIMING-18`(외부 출력 지연이 지정되지 않은 출력, 예상 34개)과 `CFGBVS-1`(설정 뱅크 전압 속성 미지정)이 보고될 수 있다. 이름·원인·범위를 실험 후 레포트에 남기고, `CFGBVS`는 보드 회로도를 확인해 값을 정한다(경고를 없애려고 임의의 값을 넣지 않는다).

### 5.2 모드별 예상 LED 동작

입력 스위치를 먼저 정한 뒤 버튼을 누르고 놓는다. 버튼은 약 20 ms 안정 확인 뒤 반영된다.

| MODE (내부) | 조작 | 예상 LED |
|---|---|---|
| 01 (0) | K4, `sw[0]=0`, N4 | `LED[3:0]`=0001, 다시 N4마다 +1, 15 다음 0 |
| 01 | `sw[0]=1`, N4 | 1씩 감소, 0에서 15 |
| 02 (1) | N4 없이 관찰 | LED0 500 Hz, LED1 100 Hz, LED2 20 Hz, LED3 1 Hz(0.5초 켜짐/꺼짐), LED4 1 ms 폭 tick. 빠른 것은 측정 장비·파형으로 확인 |
| 03 (2) | `sw=A1` N4 → `sw=33` N4 → N4 | `A0` → `3A` → `33` |
| 04 (3) | `sw[7]=1` N4 → `sw[7]=0` N4 | `LED[3:0]` = 1000 → 0100 |
| 05 (4) | `sw=A1` N4 → `sw=A0` N4 두 번 | `A1` → `40` → `81` (LED0=serial_out) |
| 06 (5) | `sw[7]=1`만 → N4 세 번 | 00 → 01 → 10 → 00 (스위치만으로는 안 바뀜) |
| 07 (6) | `sw[7]` 변경만 | 버튼 없이 LED[1:0]이 00 ↔ 10으로 변함(SW 동기화 지연 있음). N4로 state 변화 |
| 08 (7) | `sw[7:4]=9` | 첫 자리(COM[7])부터 9, 1, 2, 3, 4, 5, 6, 7 순 스캔, `LED[2:0]`=index. 1 kHz에서 약 16 ms에 한 바퀴 |
| 전체 | N8 반복 | MODE 01 → … → 08 → 01, 모드마다 LCD 이름 변경, 새 모드로 넘어갈 때 상태 초기화 |

LCD 첫 줄은 `MODE 0n`, 둘째 줄은 위 표의 이름이다. 카메라 줄무늬나 일부 자리 누락은 촬영 주기와 스캔 주기의 차이일 수 있다.

### 5.3 촬영 계획

1. K4 초기화 후 LCD MODE 01과 카운터 동작.
2. N8을 누르고 놓아 다음 이름으로 바뀌는 장면(회로 한 단계는 N4).
3. 여덟 모드마다 LCD 이름, 스위치 입력, 출력을 함께.
4. MODE 08의 여덟 자리와 MODE 01로 돌아갈 때 카운터 초기화.

실제 기록한 bit의 경로·해시와 사진·영상 링크는 실험 후 레포트에 연결한다.
