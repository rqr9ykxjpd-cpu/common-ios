#!/usr/bin/env python3
"""Markdown kaynaklardan GitHub Pages'in sunacağı HTML sayfaları üretir.

Metinlerin tek kaynağı .md dosyaları; HTML elle düzenlenmez, bu betikle
yeniden üretilir:  python3 docs/olustur.py
"""
import re, pathlib

KLASOR = pathlib.Path(__file__).parent
SAYFALAR = [("gizlilik", "Gizlilik Politikası"), ("kosullar", "Kullanım Koşulları")]

# İngilizce sürümler. Uygulamanın arayüzü Türkçe; bunlar App Store incelemesi ve
# Türkçe bilmeyen okuyucular için. Türkçe metin esas kabul ediliyor.
INGILIZCE = [("privacy", "Privacy Policy"), ("terms", "Terms of Use")]

KALIP = """<!doctype html>
<html lang="tr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{baslik} — Bond</title>
<style>
  :root {{ color-scheme: light dark; }}
  body {{ margin: 0 auto; padding: 2.5rem 1.25rem 4rem; max-width: 44rem;
         font: 17px/1.65 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
         color: #1a1a1a; background: #fbfaf7; }}
  @media (prefers-color-scheme: dark) {{ body {{ color: #ececec; background: #16161a; }} }}
  h1 {{ font-size: 1.9rem; line-height: 1.2; margin: 0 0 .4rem; }}
  h2 {{ font-size: 1.2rem; margin: 2.2rem 0 .6rem; }}
  a {{ color: #6b4df6; }}
  @media (prefers-color-scheme: dark) {{ a {{ color: #a99bff; }} }}
  ul {{ padding-left: 1.2rem; }}
  li {{ margin: .3rem 0; }}
  nav {{ margin-bottom: 2.5rem; font-size: .95rem; }}
  .tarih {{ color: #7a7a7a; font-size: .95rem; margin-top: 0; }}
</style>
</head>
<body>
<nav><a href="./">Bond</a></nav>
{govde}
</body>
</html>
"""

def donustur(md: str) -> str:
    md = re.sub(r"<!--.*?-->", "", md, flags=re.S)          # yorumlar sayfaya çıkmasın
    parcalar, liste = [], []

    def listeyi_kapat():
        if liste:
            parcalar.append("<ul>\n" + "\n".join(f"  <li>{x}</li>" for x in liste) + "\n</ul>")
            liste.clear()

    def satir_ici(t: str) -> str:
        t = t.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        return re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", t)

    for blok in re.split(r"\n\s*\n", md.strip()):
        blok = blok.strip()
        if not blok:
            continue
        if blok.startswith("# "):
            listeyi_kapat(); parcalar.append(f"<h1>{satir_ici(blok[2:])}</h1>")
        elif blok.startswith("## "):
            listeyi_kapat(); parcalar.append(f"<h2>{satir_ici(blok[3:])}</h2>")
        elif blok.startswith("- "):
            for satir in blok.split("\n"):
                if satir.strip().startswith("- "):
                    liste.append(satir_ici(satir.strip()[2:]))
                elif liste:
                    liste[-1] += " " + satir_ici(satir.strip())
        else:
            listeyi_kapat()
            metin = satir_ici(" ".join(blok.split("\n")))
            sinif = ' class="tarih"' if metin.startswith("<strong>Son güncelleme") else ""
            parcalar.append(f"<p{sinif}>{metin}</p>")
    listeyi_kapat()
    return "\n".join(parcalar)

for ad, baslik in SAYFALAR:
    kaynak = (KLASOR / f"{ad}.md").read_text(encoding="utf-8")
    (KLASOR / f"{ad}.html").write_text(
        KALIP.format(baslik=baslik, govde=donustur(kaynak)), encoding="utf-8")
    print(f"  {ad}.html üretildi")

for ad, baslik in INGILIZCE:
    kaynak = (KLASOR / "en" / f"{ad}.md").read_text(encoding="utf-8")
    (KLASOR / "en" / f"{ad}.html").write_text(
        KALIP.format(baslik=baslik, govde=donustur(kaynak)).replace('lang="tr"', 'lang="en"'),
        encoding="utf-8")
    print(f"  en/{ad}.html üretildi")

# --- Uygulama içi metinler -------------------------------------------------
# Aynı .md dosyalarından Swift üretiliyor. Metni koda elle kopyalamak, web
# sayfasıyla uygulama içindeki metnin zamanla ayrışması demekti.

def swift_kacir(t: str) -> str:
    return t.replace("\\", "\\\\").replace('"', '\\"')


def bloklar(md: str):
    md = re.sub(r"<!--.*?-->", "", md, flags=re.S)
    cikti = []
    for blok in re.split(r"\n\s*\n", md.strip()):
        blok = blok.strip()
        if not blok:
            continue
        if blok.startswith("# "):
            cikti.append(("baslik", blok[2:]))
        elif blok.startswith("## "):
            cikti.append(("altbaslik", blok[3:]))
        elif blok.startswith("- "):
            for satir in blok.split("\n"):
                satir = satir.strip()
                if satir.startswith("- "):
                    cikti.append(("madde", satir[2:]))
                elif cikti and cikti[-1][0] == "madde":
                    cikti[-1] = ("madde", cikti[-1][1] + " " + satir)
        else:
            cikti.append(("paragraf", " ".join(blok.split("\n"))))
    return cikti


satirlar = [
    "// Bu dosya `docs/olustur.py` tarafından üretiliyor. Elle düzenleme —",
    "// kaynak metinler docs/gizlilik.md, docs/kosullar.md, docs/en/privacy.md, docs/en/terms.md.",
    "",
    "enum LegalBlock {",
    "    case baslik(String)",
    "    case altbaslik(String)",
    "    case paragraf(String)",
    "    case madde(String)",
    "}",
    "",
    "enum LegalTexts {",
]
for ad, _ in SAYFALAR:
    kaynak = (KLASOR / f"{ad}.md").read_text(encoding="utf-8")
    satirlar.append(f"    static let {ad}: [LegalBlock] = [")
    for tur, metin in bloklar(kaynak):
        metin = metin.replace("**", "")
        satirlar.append(f'        .{tur}("{swift_kacir(metin)}"),')
    satirlar.append("    ]")
    satirlar.append("")
for ad, _ in INGILIZCE:
    kaynak = (KLASOR / "en" / f"{ad}.md").read_text(encoding="utf-8")
    satirlar.append(f"    static let {ad}: [LegalBlock] = [")
    for tur, metin in bloklar(kaynak):
        metin = metin.replace("**", "")
        satirlar.append(f'        .{tur}("{swift_kacir(metin)}"),')
    satirlar.append("    ]")
    satirlar.append("")
satirlar.append("}")

hedef = KLASOR.parent / "Bond" / "Core" / "Components" / "LegalTexts.swift"
hedef.write_text("\n".join(satirlar) + "\n", encoding="utf-8")
print(f"  {hedef.relative_to(KLASOR.parent)} üretildi")
