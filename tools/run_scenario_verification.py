# -*- coding: utf-8 -*-
"""
NODEVERSE Scenario-Driven Automated Bot (Simulator) Verification & PDF Report Generator
Usage:
  python tools/run_scenario_verification.py --scenario scenarios/default_full_scenario.json
  python tools/run_scenario_verification.py --scenario scenarios/default_full_scenario.json --visual
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    KeepTogether,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_GODOT_EXE = Path(r"C:\Users\Playdata\Desktop\Godot_v4.7.2-stable_win64_console.exe")
DESKTOP_DIR = Path(r"C:\Users\Playdata\Desktop")


def register_korean_fonts() -> tuple[str, str]:
    reg_path = r"C:\Windows\Fonts\malgun.ttf"
    bold_path = r"C:\Windows\Fonts\malgunbd.ttf"
    if os.path.exists(reg_path) and os.path.exists(bold_path):
        pdfmetrics.registerFont(TTFont("Malgun", reg_path))
        pdfmetrics.registerFont(TTFont("MalgunBold", bold_path))
        return "Malgun", "MalgunBold"
    return "Helvetica", "Helvetica-Bold"


def run_godot_bot(godot_exe: Path, scenario_file: Path, out_json: Path, visual: bool = False) -> int:
    cmd = [
        str(godot_exe),
        "--path",
        str(PROJECT_ROOT),
    ]
    if not visual:
        cmd.insert(1, "--headless")
    else:
        cmd.extend(["--resolution", "1280x720"])

    rel_scen = "res://" + scenario_file.resolve().relative_to(PROJECT_ROOT).as_posix()
    rel_out = "res://" + out_json.resolve().relative_to(PROJECT_ROOT).as_posix()

    cmd.extend([
        "--script",
        "res://scripts/tools/scenario_bot_runner.gd",
        "--",
        f"--scenario={rel_scen}",
        f"--out={rel_out}",
    ])
    if visual:
        cmd.append("--visual")

    print(f"[ORCHESTRATOR] Executing Godot Bot Runner ({'VISUAL' if visual else 'HEADLESS'})...")
    print(f"[ORCHESTRATOR] Scenario: {scenario_file}")
    proc = subprocess.run(cmd, cwd=str(PROJECT_ROOT))
    return proc.returncode


def build_pdf_report(result_data: dict, pdf_path: Path) -> None:
    font_reg, font_bold = register_korean_fonts()

    PRIMARY = colors.HexColor("#0F4C5C")
    PRIMARY_LIGHT = colors.HexColor("#E8F3F6")
    ACCENT = colors.HexColor("#1B8A6B")
    ACCENT_BG = colors.HexColor("#EAF7F2")
    FAIL_RED = colors.HexColor("#C0392B")
    FAIL_BG = colors.HexColor("#FDEDEC")
    TEXT_DARK = colors.HexColor("#1E293B")
    TEXT_MUTED = colors.HexColor("#64748B")
    BORDER = colors.HexColor("#CBD5E1")
    ROW_ALT = colors.HexColor("#F8FAFC")

    st_kicker = ParagraphStyle(
        "Kicker",
        fontName=font_bold,
        fontSize=8.5,
        leading=11,
        textColor=PRIMARY,
    )
    st_title = ParagraphStyle(
        "Title",
        fontName=font_bold,
        fontSize=15.5,
        leading=21,
        textColor=TEXT_DARK,
        spaceAfter=2,
    )
    st_sec = ParagraphStyle(
        "Sec",
        fontName=font_bold,
        fontSize=10.5,
        leading=14,
        textColor=PRIMARY,
        spaceBefore=7,
        spaceAfter=4,
    )
    st_th = ParagraphStyle(
        "TH",
        fontName=font_bold,
        fontSize=8.0,
        leading=10.5,
        textColor=colors.white,
        alignment=TA_CENTER,
    )
    st_td = ParagraphStyle(
        "TD",
        fontName=font_reg,
        fontSize=7.7,
        leading=10.5,
        textColor=TEXT_DARK,
    )
    st_td_bold = ParagraphStyle(
        "TDBold",
        fontName=font_bold,
        fontSize=7.8,
        leading=10.5,
        textColor=TEXT_DARK,
    )
    st_td_center = ParagraphStyle(
        "TDCenter",
        fontName=font_bold,
        fontSize=7.8,
        leading=10.5,
        textColor=TEXT_DARK,
        alignment=TA_CENTER,
    )
    st_pass = ParagraphStyle(
        "Pass",
        fontName=font_bold,
        fontSize=8.0,
        leading=10.5,
        textColor=ACCENT,
        alignment=TA_CENTER,
    )
    st_fail = ParagraphStyle(
        "Fail",
        fontName=font_bold,
        fontSize=8.0,
        leading=10.5,
        textColor=FAIL_RED,
        alignment=TA_CENTER,
    )

    meta = result_data.get("meta", {})
    summary = result_data.get("summary", {})
    steps = result_data.get("steps", [])

    def draw_footer(canvas, doc):
        canvas.saveState()
        canvas.setStrokeColor(BORDER)
        canvas.setLineWidth(0.5)
        canvas.line(13 * mm, 11 * mm, A4[0] - 13 * mm, 11 * mm)
        canvas.setFont(font_reg, 7.5)
        canvas.setFillColor(TEXT_MUTED)
        canvas.drawString(
            13 * mm,
            7 * mm,
            f"NODEVERSE 시나리오 기반 자동화 봇(시뮬레이터) 테스트 결과서 · {meta.get('scenario_id', 'NV-BOT-E2E-001')}",
        )
        canvas.drawRightString(A4[0] - 13 * mm, 7 * mm, f"Page {doc.page}")
        canvas.restoreState()

    pdf_path.parent.mkdir(parents=True, exist_ok=True)
    doc = SimpleDocTemplate(
        str(pdf_path),
        pagesize=A4,
        leftMargin=13 * mm,
        rightMargin=13 * mm,
        topMargin=12 * mm,
        bottomMargin=15 * mm,
    )

    story = []
    story.append(
        Paragraph(
            f"NODEVERSE QA AUTOMATION REPORT · {meta.get('scenario_id', 'NV-BOT-E2E-001')}",
            st_kicker,
        )
    )
    story.append(Paragraph("NODEVERSE 시나리오 기반 자동화 봇(시뮬레이터) 테스트 결과서", st_title))
    story.append(Spacer(1, 2 * mm))

    # 1. Execution Metadata Table
    story.append(Paragraph("1. 테스트 실행 환경 및 시나리오 메타 정보", st_sec))
    meta_rows = [
        [
            Paragraph("시나리오 ID / 제목", st_td_bold),
            Paragraph(f"{meta.get('scenario_id', '')} — {meta.get('title', '')}", st_td),
            Paragraph("실행 일시", st_td_bold),
            Paragraph(str(meta.get("executed_at", datetime.now().strftime("%Y-%m-%d %H:%M:%S"))), st_td),
        ],
        [
            Paragraph("실행 모드 / 엔진", st_td_bold),
            Paragraph(f"{meta.get('mode', '')} / {meta.get('engine', '')}", st_td),
            Paragraph("빌드 / 콘텐츠 버전", st_td_bold),
            Paragraph(f"v{meta.get('build_version', '0.3.0')} (content: {meta.get('content_version', 'base')})", st_td),
        ],
        [
            Paragraph("Django API 서버", st_td_bold),
            Paragraph(str(meta.get("django_server", "http://192.168.0.29:8000")), st_td),
            Paragraph("이벤트 수집 서버", st_td_bold),
            Paragraph(str(meta.get("collector_server", "http://192.168.0.81:8000/v2/events")), st_td),
        ],
    ]
    t_meta = Table(meta_rows, colWidths=[30 * mm, 72 * mm, 30 * mm, 52 * mm])
    t_meta.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (0, -1), PRIMARY_LIGHT),
                ("BACKGROUND", (2, 0), (2, -1), PRIMARY_LIGHT),
                ("GRID", (0, 0), (-1, -1), 0.4, BORDER),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                ("TOPPADDING", (0, 0), (-1, -1), 4),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
                ("LEFTPADDING", (0, 0), (-1, -1), 5),
                ("RIGHTPADDING", (0, 0), (-1, -1), 5),
            ]
        )
    )
    story.append(t_meta)

    # 2. Overall Summary KPI Box
    story.append(Paragraph("2. 종합 검증 결과 요약 (Executive Summary)", st_sec))
    overall = str(summary.get("overall_status", "PASS"))
    total_s = int(summary.get("total_steps", 0))
    pass_s = int(summary.get("passed_steps", 0))
    fail_s = int(summary.get("failed_steps", 0))
    rate = float(summary.get("pass_rate_percent", 100.0))
    dur_ms = int(summary.get("total_duration_ms", 0))

    kpi_rows = [
        [
            Paragraph("총 시나리오 스텝", st_th),
            Paragraph("성공 (PASS)", st_th),
            Paragraph("실패 (FAIL)", st_th),
            Paragraph("최종 통과율", st_th),
            Paragraph("총 소요 시간", st_th),
            Paragraph("종합 판정", st_th),
        ],
        [
            Paragraph(f"{total_s} 건", st_td_center),
            Paragraph(f"{pass_s} 건", st_pass),
            Paragraph(f"{fail_s} 건", st_fail if fail_s > 0 else st_td_center),
            Paragraph(f"{rate:.1f}%", st_pass if fail_s == 0 else st_fail),
            Paragraph(f"{dur_ms:,} ms ({dur_ms / 1000.0:.2f}s)", st_td_center),
            Paragraph(f"최종 합격 ({overall})" if overall == "PASS" else f"불합격 ({overall})", st_pass if overall == "PASS" else st_fail),
        ],
    ]
    t_kpi = Table(kpi_rows, colWidths=[29 * mm, 29 * mm, 29 * mm, 30 * mm, 35 * mm, 32 * mm])
    t_kpi.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), PRIMARY),
                ("BACKGROUND", (0, 1), (-1, 1), ACCENT_BG if overall == "PASS" else FAIL_BG),
                ("GRID", (0, 0), (-1, -1), 0.5, BORDER),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                ("TOPPADDING", (0, 0), (-1, -1), 5),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
            ]
        )
    )
    story.append(t_kpi)

    # 3. Step-by-Step Verification Table
    story.append(Paragraph("3. 시나리오 단계별 상세 검증 결과 표 (Step-by-Step Verification)", st_sec))
    step_rows = [
        [
            Paragraph("Step", st_th),
            Paragraph("분류", st_th),
            Paragraph("시나리오 검증 항목명", st_th),
            Paragraph("기대 결과 (Expected)", st_th),
            Paragraph("실제 측정 결과 (Actual)", st_th),
            Paragraph("시간", st_th),
            Paragraph("판정", st_th),
        ]
    ]

    def esc(text: str) -> str:
        return str(text).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

    for idx, st in enumerate(steps):
        is_ok = bool(st.get("passed", False))
        step_rows.append(
            [
                Paragraph(esc(st.get("step_id", f"S{idx+1:02d}")), st_td_center),
                Paragraph(esc(st.get("category", "")), st_td_center),
                Paragraph(esc(st.get("name", "")), st_td_bold),
                Paragraph(esc(st.get("expected", "")), st_td),
                Paragraph(esc(st.get("actual", "")), st_td),
                Paragraph(f"{int(st.get('duration_ms', 0)):,}ms", st_td_center),
                Paragraph("PASS" if is_ok else "FAIL", st_pass if is_ok else st_fail),
            ]
        )

    t_steps = Table(
        step_rows,
        colWidths=[11 * mm, 19 * mm, 41 * mm, 43.5 * mm, 43.5 * mm, 14 * mm, 12 * mm],
        repeatRows=1,
    )
    step_style = [
        ("BACKGROUND", (0, 0), (-1, 0), PRIMARY),
        ("GRID", (0, 0), (-1, -1), 0.4, BORDER),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("TOPPADDING", (0, 0), (-1, -1), 3.5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 3.5),
        ("LEFTPADDING", (0, 0), (-1, -1), 4),
        ("RIGHTPADDING", (0, 0), (-1, -1), 4),
    ]
    for i in range(1, len(step_rows)):
        is_ok = bool(steps[i - 1].get("passed", False))
        if i % 2 == 0:
            step_style.append(("BACKGROUND", (0, i), (-2, i), ROW_ALT))
        step_style.append(("BACKGROUND", (-1, i), (-1, i), ACCENT_BG if is_ok else FAIL_BG))
    t_steps.setStyle(TableStyle(step_style))
    story.append(t_steps)

    doc.build(story, onFirstPage=draw_footer, onLaterPages=draw_footer)
    print(f"[REPORTER] PDF Test Result Report generated: {pdf_path}")


def main() -> int:
    parser = argparse.ArgumentParser(description="NODEVERSE Scenario Bot Verification & PDF Reporter")
    parser.add_argument(
        "--scenario",
        type=str,
        default="scenarios/default_full_scenario.json",
        help="Path to scenario JSON file",
    )
    parser.add_argument(
        "--godot",
        type=str,
        default=str(DEFAULT_GODOT_EXE),
        help="Path to Godot 4.7.2 console executable",
    )
    parser.add_argument(
        "--visual",
        action="store_true",
        help="Run bot in visual 1280x720 window with screenshot capture",
    )
    parser.add_argument(
        "--pdf-out",
        type=str,
        default="output/reports/NODEVERSE_자동화봇_테스트결과서.pdf",
        help="Output PDF report path",
    )
    args = parser.parse_args()

    scenario_file = (PROJECT_ROOT / args.scenario).resolve() if not os.path.isabs(args.scenario) else Path(args.scenario)
    out_json = PROJECT_ROOT / "output" / "reports" / "latest_bot_result.json"
    pdf_out = (PROJECT_ROOT / args.pdf_out).resolve() if not os.path.isabs(args.pdf_out) else Path(args.pdf_out)
    godot_exe = Path(args.godot)

    if not scenario_file.exists():
        print(f"[ERROR] Scenario file not found: {scenario_file}")
        return 1

    rc = run_godot_bot(godot_exe, scenario_file, out_json, visual=args.visual)
    if not out_json.exists():
        print(f"[ERROR] Bot result JSON was not created: {out_json}")
        return 1

    with open(out_json, "r", encoding="utf-8") as f:
        result_data = json.load(f)

    build_pdf_report(result_data, pdf_out)

    # Also copy to user's Desktop for instant inspection
    if DESKTOP_DIR.exists():
        desktop_pdf = DESKTOP_DIR / pdf_out.name
        shutil.copyfile(pdf_out, desktop_pdf)
        print(f"[REPORTER] Copied PDF report to Desktop: {desktop_pdf}")

    return rc


if __name__ == "__main__":
    sys.exit(main())
