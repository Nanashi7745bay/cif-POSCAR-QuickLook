# CrystalQuickLook for macOS 💎 (v1.1)

macOSのFinder上で、**CIFファイル**（Crystallographic Information File）や**POSCARファイル**（VASP結晶構造ファイル）を選択して**スペースキー（Spacebar）**を押すだけで、結晶構造を瞬時に美しい3Dで確認できるQuickLook拡張機能（Preview Extension）＆軽量ビューアです。

VESTAやOvito等の重いGUIソフトを起動することなく、ファイルの構造、単位格子、格子定数、化学式を爆速で確認できます。

**Important Notice!!!**
このレポジトリは生成AI機能(Antigravity)によって書かれています。誤りがある可能性があり、加えて苦手な方は利用を控えてください。

---

## 🎨 v1.1 新機能: 着せ替えテーマ機能 (Render Styles)

HUD上のセグメントボタン、またはキーボードショートカット（`T` や `1`/`2`/`3`）で即座にスタイルを切り替えられます。設定したスタイルは次回以降も自動で保存・維持されます。

| スタイル名 | キー | 背景色 | 特徴 | 用途 |
|---|:---:|:---:|---|---|
| **Studio Dark** | `1` | 深いダークスレート | モダンな暗背景＋スタジオライティング（Blinn/PBR）＋CPKカラー | 暗い環境での日常作業・画面見栄え |
| **VESTA Style** | `2` | 優しいシアン系ライトグレー | **VESTA互換カラーパレット**（Si:スカイブルー、Ti:ターコイズ等）＋シャープな白ハイライト光沢＋ダーク枠線 | VESTA慣れした研究者の日常チェック |
| **Flat White (No Shade)** | `3` | **純白 (#FFFFFF)** | **No shade, No lighting (完全フラット)**＋くっきり黒色格子枠線＋明瞭ソリッドカラー | **論文投稿・研究ノート・印刷・発表スライド用** |

---

## ✨ 主な特徴 (Features)

1. **Spaceキーで即座に3Dプレビュー (QuickLook Preview Extension)**
   - Finderで `.cif`、`POSCAR`、`CONTCAR`、`.vasp` ファイルを選んでSpaceキーを押すだけ。
2. **SceneKitによる完全ネイティブ・高品位3D描画**
   - Metalアクセラレーションによる超滑らかな60FPSレンダリング。
   - マウスドラッグで3D回転、2本指スクロール/ピンチで拡大縮小、Shift+ドラッグで平行移動。
3. **単位格子（Unit Cell）と結晶軸の可視化**
   - 原点からの3軸を分かりやすくカラー表示：**a軸（赤）**、**b軸（緑）**、**c軸（青）**。
   - 単位格子の境界（面・稜・頂点）に位置する原子を自動補完し、完全な閉じた結晶セル（Periodic boundary filling）を描画。
4. **化学結合（Bonds）の自動生成**
   - 共有結合半径に基づく距離判定により、四面体配位や八面体配位などの結合ネットワークをシリンダーで自動描画。
5. **周期表全元素対応のカラーパレット & 原子サイズ**
   - 標準CPKカラーおよびVESTA互換パレットを網羅。
6. **空間群対称操作の自動展開 (CIF Symop Expansion)**
   - 非対称単位（Asymmetric unit）のみが記述されたCIF（ICSDやCOD、Materials Projectなど）でも、空間群の対称操作（`_space_group_symop_operation_xyz` 等）を自動展開して単位胞全体を復元。
7. **POSCAR（VASP 4 & 5）完全対応**
   - Direct（分数座標）およびCartesian（直交座標）の両形式に対応。
   - Selective dynamics行の有無も自動判定。
8. **洗練されたガラスHUDオーバーレイ (Visual Effect View)**
   - 化学式（縮約組成式）、格子パラメータ（$a, b, c$ [Å], $\alpha, \beta, \gamma$ [°]）、体積 $V$ [Å³]、空間群、元素ごとの原子数を表示。
   - 背景色（ダーク／白）に応じてHUDも最適なコントラストに自動追従。
   - スタイル切り替えコントロール（`Studio` / `VESTA` / `Flat (White)`）を搭載。
   - ワンクリック視点切り替えボタン（`Reset`, `a-view`, `b-view`, `c-view`）を搭載。
9. **スタンドアロンアプリとしても動作**
   - `CrystalQuickLook.app` を直接開いて、ドラッグ＆ドロップでファイルを開くことも可能。

---

## 🚀 インストール手順 (Installation)

ターミナルを開き、本リポジトリのディレクトリで以下のインストールスクリプトを実行してください。

```bash
./install.sh
```

または `make` を使用する場合：
```bash
make install
```

これにより以下が自動実行されます：
1. `build/CrystalQuickLook.app` のビルド
2. `~/Applications/` へのインストール
3. QuickLook Extension（`CrystalQuickLookPreview.appex`）のシステム登録
4. QuickLook デーモン（`quicklookd`）のキャッシュリセット

---

## 🎮 操作方法・ショートカット (Controls)

プレビュー画面（またはアプリウィンドウ）で直感的に操作できます：

| キー / 操作 | 動作 |
|:---:|---|
| **マウスクリック＆ドラッグ** | 結晶構造を自由自在に3D回転 |
| **2本指スクロール / ピンチ** | 拡大・縮小（ズームイン / ズームアウト） |
| **Shift + ドラッグ** | 平行移動（パン操作） |
| **`T` キー または `S` キー** | **着せ替えスタイルを順次切り替え**（Studio ⇄ VESTA ⇄ Flat White） |
| **`1` キー** | **Studio Dark** スタイルに切り替え |
| **`2` キー** | **VESTA Compatible** スタイルに切り替え |
| **`3` キー** | **Flat White (No Shade, No Lighting)** スタイルに切り替え |
| **`R` キー** | 初期アングル（斜視図）にリセット |
| **`A` キー** | a軸に沿った視点（bc面）に切り替え |
| **`B` キー** | b軸に沿った視点（ac面）に切り替え |
| **`C` キー** | c軸に沿った視点（ab面）に切り替え |

---

## 📁 動作確認用サンプル (Sample Files)

`Samples/` ディレクトリに各種結晶構造のサンプルが含まれています：

- `Samples/Si_diamond.cif`: シリコン（ダイヤモンド構造、空間群 $Fd\bar{3}m$）
- `Samples/SrTiO3_perovskite.cif`: チタン酸ストロンチウム（ペロブスカイト構造、立方晶 $Pm\bar{3}m$）
- `Samples/NaCl.cif`: 塩化ナトリウム（岩塩構造、面心立方 $Fm\bar{3}m$）
- `Samples/POSCAR_Si`: シリコンの8原子単位格子 (VASP POSCAR)
- `Samples/POSCAR_TiO2`: ルチル型酸化チタン $TiO_2$ (VASP POSCAR)

テストスクリプトの実行：
```bash
make test
```

---

## 🗑️ アンインストール (Uninstallation)

```bash
make uninstall
```
