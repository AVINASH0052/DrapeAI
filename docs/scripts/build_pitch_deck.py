#!/usr/bin/env python3
"""Build Sugatai pitch deck using Midnight Masala app colors."""

from pathlib import Path

from reportlab.lib.pagesizes import landscape, letter
from reportlab.lib.units import inch
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas

pdfmetrics.registerFont(TTFont("Georgia", "/System/Library/Fonts/Supplemental/Georgia.ttf"))
pdfmetrics.registerFont(
    TTFont("GeorgiaBold", "/System/Library/Fonts/Supplemental/Georgia Bold.ttf")
)
pdfmetrics.registerFont(TTFont("Arial", "/System/Library/Fonts/Supplemental/Arial.ttf"))
pdfmetrics.registerFont(
    TTFont("ArialBold", "/System/Library/Fonts/Supplemental/Arial Bold.ttf")
)

OUT = Path(__file__).resolve().parents[1] / "sugatai-pitch-deck.pdf"
W, H = landscape(letter)
TOTAL = 8

# AppColors light theme
BG = (0xFD / 255, 0xF6 / 255, 0xEE / 255)
BG_WARM = (0xF5 / 255, 0xEB / 255, 0xE0 / 255)
CARD = (1, 1, 1)
BORDER = (0xE8 / 255, 0xDD / 255, 0xD0 / 255)
INK = (0x0C / 255, 0x0A / 255, 0x14 / 255)
INK2 = (0x4A / 255, 0x44 / 255, 0x58 / 255)
INK3 = (0x8A / 255, 0x82 / 255, 0x99 / 255)
ORANGE = (1.0, 0x5C / 255, 0.0)
ORANGE_SOFT = (1.0, 0xED / 255, 0xE3 / 255)
PINK = (1.0, 0.0, 0x6E / 255)
PINK_SOFT = (1.0, 0xE8 / 255, 0xF2 / 255)
LIME = (0.0, 0xE5 / 255, 0xA0 / 255)
LIME_SOFT = (0xE0 / 255, 1.0, 0xF5 / 255)


def build() -> None:
    c = canvas.Canvas(str(OUT), pagesize=landscape(letter))

    def fill(rgb):
        c.setFillColorRGB(*rgb)

    def bg():
        fill(BG)
        c.rect(0, 0, W, H, fill=1, stroke=0)

    def footer(n):
        c.setStrokeColorRGB(*BORDER)
        c.setLineWidth(1)
        c.line(0.65 * inch, 0.55 * inch, W - 0.5 * inch, 0.55 * inch)
        c.setFont("Arial", 9)
        fill(INK3)
        c.drawString(0.65 * inch, 0.32 * inch, "Sugatai")
        c.drawCentredString(W / 2, 0.32 * inch, "sugatai.com")
        c.drawRightString(W - 0.5 * inch, 0.32 * inch, f"{n}/{TOTAL}")

    def h1(text):
        fill(INK)
        c.setFont("GeorgiaBold", 28)
        c.drawString(0.65 * inch, H - 0.9 * inch, text)
        fill(ORANGE)
        c.rect(0.65 * inch, H - 1.05 * inch, 1.35 * inch, 3.5, fill=1, stroke=0)

    def pill(x, y, text, soft, fg):
        c.setFont("ArialBold", 9)
        w = c.stringWidth(text, "ArialBold", 9) + 18
        fill(soft)
        c.roundRect(x, y, w, 18, 9, fill=1, stroke=0)
        fill(fg)
        c.drawString(x + 9, y + 5, text)
        return w

    def box(x, y, w, h, title, lines, accent):
        fill(CARD)
        c.setStrokeColorRGB(*BORDER)
        c.setLineWidth(1)
        c.roundRect(x, y, w, h, 10, fill=1, stroke=1)
        fill(accent)
        c.rect(x, y + h - 5, w, 5, fill=1, stroke=0)
        fill(INK)
        c.setFont("GeorgiaBold", 12)
        c.drawString(x + 14, y + h - 28, title)
        fill(INK2)
        c.setFont("Arial", 10)
        ty = y + h - 48
        for line in lines:
            c.drawString(x + 14, ty, line)
            ty -= 14

    # 1 Cover
    bg()
    fill(BG_WARM)
    c.rect(0, 0, W * 0.42, H, fill=1, stroke=0)
    fill(ORANGE)
    c.rect(0, 0, 8, H, fill=1, stroke=0)
    fill(INK)
    c.setFont("GeorgiaBold", 44)
    c.drawString(0.55 * inch, H * 0.58, "Sugatai")
    fill(INK2)
    c.setFont("Arial", 13)
    c.drawString(0.55 * inch, H * 0.58 - 28, "see your look, before you wear it")
    pill(0.55 * inch, H * 0.58 - 58, "WARDROBE", ORANGE_SOFT, ORANGE)
    pill(0.55 * inch + 88, H * 0.58 - 58, "OUTFITS", PINK_SOFT, PINK)
    pill(0.55 * inch + 168, H * 0.58 - 58, "TRY ON", LIME_SOFT, (0, 0.55, 0.42))
    fill(INK)
    c.setFont("GeorgiaBold", 22)
    c.drawString(W * 0.48, H * 0.62, "Your closet.")
    c.drawString(W * 0.48, H * 0.62 - 30, "Styled.")
    c.drawString(W * 0.48, H * 0.62 - 60, "On you.")
    fill(INK2)
    c.setFont("Arial", 12)
    c.drawString(W * 0.48, H * 0.62 - 105, "Photograph what you own.")
    c.drawString(W * 0.48, H * 0.62 - 123, "Get outfits. Preview on your photo.")
    fill(INK3)
    c.setFont("Arial", 10)
    c.drawString(W * 0.48, 0.7 * inch, "avinash@sugatai.com")
    c.drawString(W * 0.48, 0.5 * inch, "Bootstrapped · Pre revenue")
    c.showPage()

    # 2 Problem
    bg()
    h1("Mornings are still hard")
    footer(2)
    fill(INK2)
    c.setFont("Arial", 13)
    y = H - 1.55 * inch
    for line in [
        "People already own more clothes than they wear.",
        "They still waste time deciding, then buy more to feel new.",
        "",
        "Closet apps mostly catalog pieces and stop there.",
        "Try on tools mostly sell catalog SKUs, not your own rack.",
        "Human stylists are slow and priced for special occasions.",
        "",
        "The daily job is simple and still unmet: open the app, get a look",
        "from your stuff, see it on your body, leave the house.",
    ]:
        if not line:
            y -= 10
            continue
        c.drawString(0.65 * inch, y, line)
        y -= 22
    c.showPage()

    # 3 Product
    bg()
    h1("What you open")
    footer(3)
    box(
        0.55 * inch,
        1.15 * inch,
        2.35 * inch,
        4.35 * inch,
        "Wardrobe",
        [
            "Phone photos in",
            "Background cleaned",
            "Items tagged for you",
            "Browse by type / color",
        ],
        ORANGE,
    )
    box(
        3.05 * inch,
        1.15 * inch,
        2.35 * inch,
        4.35 * inch,
        "Outfits",
        [
            "Daily recommendations",
            "Occasion aware picks",
            "Shuffle when it misses",
            "Save into lookbooks",
        ],
        PINK,
    )
    box(
        5.55 * inch,
        1.15 * inch,
        2.35 * inch,
        4.35 * inch,
        "Try on",
        [
            "Your photo as base",
            "Garment put on you",
            "Keep what works",
            "Skip what does not",
        ],
        LIME,
    )
    c.showPage()

    # 4 Stack
    bg()
    h1("How it runs")
    footer(4)
    bits = [
        ("Mobile", "Flutter on Android and iOS"),
        ("API", "FastAPI, Postgres, Firebase login"),
        ("Tagging", "Vision models label uploads"),
        ("Styling", "Rules shortlist, model ranks"),
        ("Try on", "GPU jobs render on your photo"),
        ("Ops", "Admin for users, flags, spend"),
    ]
    y = H - 1.55 * inch
    for label, desc in bits:
        fill(ORANGE)
        c.roundRect(0.65 * inch, y - 2, 72, 16, 3, fill=1, stroke=0)
        fill(CARD)
        c.setFont("ArialBold", 9)
        c.drawCentredString(0.65 * inch + 36, y + 2, label)
        fill(INK)
        c.setFont("Arial", 12)
        c.drawString(0.65 * inch + 88, y + 1, desc)
        y -= 36
    c.showPage()

    # 5 Unique
    bg()
    h1("Where we sit alone")
    footer(5)
    items = [
        ("Own clothes first", "Start from your closet, not a brand catalog."),
        ("Finish on your body", "A pick is incomplete until you see it on you."),
        ("One morning habit", "Upload, outfit, lookbook, preview. Same place."),
        ("Built for phone photos", "Messy light and clutter are normal input."),
        ("Easy to keep paying", "Pro around the cost of one coffee a week."),
    ]
    y = H - 1.5 * inch
    for title, desc in items:
        fill(CARD)
        c.setStrokeColorRGB(*BORDER)
        c.roundRect(0.65 * inch, y - 12, W - 1.3 * inch, 48, 8, fill=1, stroke=1)
        fill(ORANGE)
        c.circle(0.95 * inch, y + 10, 5, fill=1, stroke=0)
        fill(INK)
        c.setFont("GeorgiaBold", 12)
        c.drawString(1.25 * inch, y + 14, title)
        fill(INK2)
        c.setFont("Arial", 11)
        c.drawString(1.25 * inch, y - 2, desc)
        y -= 58
    c.showPage()

    # 6 Compare
    bg()
    h1("Against the usual options")
    footer(6)
    headers = ["Job", "Sugatai", "Closet apps", "Try on tools", "Human stylist"]
    rows = [
        ["Uses your wardrobe", "Yes", "Yes", "Mostly no", "Yes"],
        ["Builds outfits for you", "Yes", "Sometimes", "No", "Yes"],
        ["Shows look on your photo", "Yes", "Rare", "Yes", "No"],
        ["Ready same morning", "Yes", "Varies", "Yes", "No"],
        ["Cost for daily use", "Low", "Low to mid", "Free to paid", "High"],
        ["One app for the loop", "Yes", "Partial", "Partial", "No"],
    ]
    x0 = 0.5 * inch
    y0 = H - 1.4 * inch
    widths = [2.0 * inch, 1.25 * inch, 1.45 * inch, 1.45 * inch, 1.45 * inch]
    rh = 0.4 * inch

    fill(INK)
    c.rect(x0, y0, sum(widths), rh, fill=1, stroke=0)
    x = x0
    for htxt, w in zip(headers, widths):
        fill(CARD)
        c.setFont("ArialBold", 9)
        c.drawString(x + 8, y0 + 12, htxt)
        x += w

    y = y0 - rh
    for r, row in enumerate(rows):
        fill(ORANGE_SOFT if r % 2 == 0 else CARD)
        c.rect(x0, y, sum(widths), rh, fill=1, stroke=0)
        x = x0
        for i, (val, w) in enumerate(zip(row, widths)):
            if i == 0:
                fill(INK)
                c.setFont("ArialBold", 9)
            elif i == 1:
                fill(ORANGE)
                c.setFont("ArialBold", 9)
            else:
                fill(INK2)
                c.setFont("Arial", 9)
            c.drawString(x + 8, y + 12, val)
            x += w
        c.setStrokeColorRGB(*BORDER)
        c.setLineWidth(0.5)
        c.line(x0, y, x0 + sum(widths), y)
        y -= rh

    fill(INK2)
    c.setFont("Arial", 10)
    c.drawString(
        0.5 * inch,
        0.85 * inch,
        "Closet apps stop at inventory. Try on tools stop at shopping. We finish the morning decision.",
    )
    c.showPage()

    # 7 NVIDIA
    bg()
    h1("Where NVIDIA fits")
    footer(7)
    fill(INK2)
    c.setFont("Arial", 12)
    y = H - 1.55 * inch
    for line in [
        "Phone photos need vision models that tolerate bad light and clutter.",
        "Try on is an image job: person photo + garment becomes a preview.",
        "That work wants GPUs when many users preview looks at once.",
        "",
        "We already route tagging and try on through GPU backed services.",
        "Inception helps raise preview quality and lower cost per render",
        "without pausing product work for infra shopping.",
        "",
        "This is compute for the screen people open the app to see.",
    ]:
        if not line:
            y -= 10
            continue
        c.drawString(0.65 * inch, y, line)
        y -= 22
    c.showPage()

    # 8 Status
    bg()
    h1("Status")
    footer(8)
    box(
        0.55 * inch,
        2.5 * inch,
        3.5 * inch,
        3.0 * inch,
        "Now",
        [
            "Bootstrapped, $0 raised",
            "No investors or incubators",
            "Founder building the product",
            "Live site + admin + API",
            "Mobile app in active build",
        ],
        ORANGE,
    )
    box(
        4.25 * inch,
        2.5 * inch,
        3.5 * inch,
        3.0 * inch,
        "Next",
        [
            "Sharper outfit picks",
            "Faster, cleaner try on",
            "Early users on Pro",
            "Keep the daily habit sticky",
        ],
        PINK,
    )
    fill(INK2)
    c.setFont("Arial", 11)
    c.drawString(
        0.65 * inch, 1.7 * inch, "Applying to Inception for GPU tooling and technical enablement."
    )
    c.drawString(0.65 * inch, 1.48 * inch, "Not raising a round through this form.")
    c.showPage()

    c.save()
    print(f"wrote {OUT} ({OUT.stat().st_size} bytes)")


if __name__ == "__main__":
    build()
