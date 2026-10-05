# -*- coding: utf-8 -*-
"""给 bromeme 的所有道具加 meme 值（越抽象/越梗的加得越多，1~10）。"""
import json, os, sys

RES = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\resources"
EFFECT_BASE = "res://items/all/cake/cake_effect_1.tres"

# my_id -> meme 值
MEME = {
    "item_brolab_wddsxc_464": 10,   # 伟大的孙笑川
    "item_brolab_cf_126": 9,        # 中指
    "item_brolab_cf_78": 9,         # 终极侮辱
    "item_brolab_fkcs_87": 9,       # 反抗孙笑川
    "item_brolab_jsly_385": 9,      # 和孙笑川同流合污
    "item_brolab_chj_506": 9,       # 初号机
    "item_brolab_item_zhou_435": 8, # 肘
    "item_brolab_sgm_273": 8,       # 石鬼面
    "item_brolab_rlsz_424": 8,      # 如来神掌
    "item_brolab_cf_448": 8,        # 嘲讽
    "item_brolab_yzdzzda_279": 8,   # 宇宙的终极答案
    "item_brolab_lwyll_93": 8,      # 李文亚理论
    "item_brolab_tdmz_174": 8,      # 土豆的九十亿个名字
    "item_brolab_ly_166": 8,        # 轮椅
    "item_brolab_tyd_480": 7,       # 天元鼎
    "item_brolab_ymdg_56": 7,       # 云面大果
    "item_brolab_dj_504": 7,        # 大脚
    "item_brolab_czdb_119": 7,      # 丙泊酚
    "item_brolab_yzdjt_427": 7,     # 宇宙的尽头
    "item_brolab_lwyh_1": 7,        # 李文亚引擎
    "item_brolab_lwysg_398": 7,     # 李文亚手稿
    "item_brolab_lwyh_373": 7,      # ”李文亚“号
    "item_brolab_dqdp_253": 7,      # 地球大炮
    "item_brolab_mrjj_14": 7,       # 末日机甲
    "item_brolab_dx_109": 7,        # 大笑
    "item_brolab_character_basketball_318": 6,  # 篮球
    "item_brolab_qgds_421": 6,      # 奇怪的蛇
    "item_brolab_tr_421": 6,        # 危险的兔人
    "item_brolab_hpzy_446": 6,      # 和平主义
    "item_brolab_gwqcb_477": 6,     # 怪物千层饼
    "item_brolab_xb_478": 6,        # 雪豹
    "item_brolab_czdb_158": 6,      # 纯正的冰
    "item_brolab_cznw_146": 6,      # 悲伤
    "item_brolab_cznw_200": 6,      # 虫族女王
    "item_brolab_tsyz_32": 6,       # 探索宇宙
    "item_brolab_ptscx_87": 5,      # 炮塔生产线
    "item_brolab_hftt_308": 5,      # 悍匪头套
    "item_brolab_ff_493": 5,        # 粪肥
    "item_brolab_zsjsll_20": 5,     # 知识就是力量
    "item_brolab_sf_134": 5,        # 身法
    "item_brolab_fn_16": 5,         # 愤怒
    "item_brolab_flw_283": 5,       # 腐烂物
    "item_brolab_qgdwyj_33": 5,     # 奇怪的望远镜
    "item_brolab_hlxq_171": 5,      # 荒凉星球
    "item_brolab_hlxq_111": 5,      # 宜居星球
    "item_brolab_ddxq_135": 5,      # 敌对星球
    "item_brolab_item_zsj_183": 4,  # 直升机
    "item_brolab_item_icetea_419": 4,   # 冰红茶
    "item_brolab_dlsds_466": 4,     # 大理石雕塑
    "item_brolab_sgd_72": 4,        # 水果店
    "item_brolab_qpd_29": 4,        # 枪炮店
    "item_brolab_ash_277": 4,       # 灰
    "item_brolab_jkcxg_323": 4,     # 巨口储蓄罐
    "item_brolab_cf_380": 4,        # 水蜡烛
    "item_brolab_msj_488": 4,       # 美食家
    "item_brolab_sxhl_315": 4,      # 瞬息活力
    "item_brolab_ycxhd_205": 4,     # 一次性护盾
    "item_brolab_htb_17": 4,        # 火腿棒
    "item_brolab_hgd_185": 4,       # 黄果冻
    "item_brolab_lgd_20": 4,        # 绿果冻
    "item_brolab_tdmz_162": 4,      # 工程学的极限
    "item_brolab_yan_262": 3,       # 烟
    "item_brolab_yan_56": 3,        # 烟
    "item_brolab_ygmy_407": 3,      # 阳光玫瑰
    "item_brolab_nlhd_43": 3,       # 能量护盾
    "item_brolab_nlhdair_62": 3,    # 能量护盾air
    "item_brolab_tz_511": 3,        # 投资
    "item_brolab_dlsj_125": 3,      # 大理石甲
    "item_brolab_mhq_320": 3,       # 灭火器
    "item_brolab_qlz_30": 3,        # 巧乐兹
    "item_brolab_cpdd_16": 3,       # 残破大盾
    "item_brolab_gcx2_342": 3,      # 进阶工程学
    "item_brolab_jxyj_447": 3,      # 继续研究
    "item_brolab_jjyj_226": 3,      # 机甲研究
    "item_brolab_fx1_191": 3,       # 研究方向：工程学
    "item_brolab_fx2_365": 3,       # 研究方向：航天学
    "item_brolab_ss_162": 2,        # 燧石
    "item_brolab_hy_39": 2,         # 火药
    "item_brolab_yl_111": 2,        # 哑铃
    "item_brolab_cf_188": 2,        # 会员卡
    "item_brolab_ztyy_24": 2,       # 钻探原油
    "item_brolab_xdt_346": 2,       # 小地图
    "item_brolab_hz_189": 2,        # 游侠徽章
    "item_brolab_hz_403": 2,        # 战士徽章
    "item_brolab_hz_231": 2,        # 召唤师徽章
    "item_brolab_hz_172": 2,        # 巫士徽章
    "item_brolab_gcx1_472": 2,      # 工程学研究
}

DEFAULT = 3


def main():
    files = sorted(f for f in os.listdir(RES) if f.endswith(".json") and not f.startswith("_"))
    total = 0
    touched = 0
    unknown = []
    for fn in files:
        path = os.path.join(RES, fn)
        data = json.load(open(path, encoding="utf-8"))
        if int(data.get("item_type", 1)) == 0:
            continue  # 只给道具加
        my_id = str(data.get("my_id", ""))
        value = MEME.get(my_id)
        if value is None:
            value = DEFAULT
            unknown.append((my_id, data.get("name", "")))
        datas = data.setdefault("datas", [])
        # 先清掉已有的 meme 效果，避免重复执行时叠加
        datas[:] = [d for d in datas
                    if not (str(d.get("changed_key_values", {}).get("key", "")) == "stat_meme")]
        datas.append({
            "base_resource_path": EFFECT_BASE,
            "changed_key_values": {"key": "stat_meme", "value": value},
        })
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write("\n")
        touched += 1
        total += value
    print("道具 %d 个已加 meme 值，合计 %d 点，平均 %.1f" % (touched, total, total / max(1, touched)))
    if unknown:
        print("用默认值 %d 的条目（%d 个）：" % (DEFAULT, len(unknown)))
        for my_id, name in unknown:
            print("   %-38s %s" % (my_id, name))


if __name__ == "__main__":
    main()
