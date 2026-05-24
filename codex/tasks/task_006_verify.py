#!/usr/bin/env python3
"""Verify task 6: feed map consistency between the script, the deployed
EnvelopOraclePyth contract, Pyth Hermes API, and the PYTH contract on mainnet."""

import json
import subprocess
import sys
import urllib.parse
import urllib.request
from decimal import Decimal

ORACLE = "0x88b50e2338911f81dff74a854d710ca709b247b6"
PYTH = "0x4305FB66699C3B2702D4d05CF36551390A4c69C6"
RPC = "https://rpc.envelop.is/eth"
ETH_BASE = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"

# (idx_in_script, symbol, token, feedId) — taken verbatim from
# script/DeployEnvelopOraclePyth.s.sol lines 52..174.
ROWS = [
    (0,  "LDO",     "0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32", "0xc63e2a7f37a04e5e614c07238bedb25dcc38927fba8fe890597a593c0b2fa4ad"),
    (1,  "ETHFI",   "0x01791F726B4103694969820be083196cC7c045fF", "0xb27578a9654246cb0a2950842b92330e9ace141c52b63829cc72d5c45a5a595a"),
    (2,  "ENA",     "0x57e114B691Db790C35207b2e685D4A43181e6061", "0xb7910ba7322db020416fcac28b48c01212fd9cc8fbcbaf7d30477ed8605f6bd4"),
    (3,  "SKY",     "0x56072C95FAA701256059aa122697B133aDEd9279", "0xa483243eed64ca27a1f6e26385b7d1e0d07e9fe264bb6903efb3efc4689d3fe7"),
    (4,  "AAVE",    "0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9", "0x2b9ab1e972a281585084148ba1389800799bd4be63b957507db1349314e47445"),
    (5,  "MORPHO",  "0x58D97B57BB95320F9a05dC918Aef65434969c2B2", "0x5b2a4c542d4a74dd11784079ef337c0403685e3114ba0d9909b5c7a7e06fdc42"),
    (6,  "SYRUP",   "0x643C4E15d7d62Ad0aBeC4a9BD4b001aA3Ef52d66", "0xed86e0c6321d790302e5d88751995ebc9079273e549005d68a83ba72e48ff1ce"),
    (7,  "EUL",     "0xd9Fcd98c322942075A5C3860693e9f4f03AAE07b", "0xa7adc417fe7e862494b488e89d88ab23f468661b63542d8f719da8f77e34c51f"),
    (8,  "SPK",     "0xc20059e0317DE91738d13af027DfC4a50781b066", "0x88a17f294aa817de3f22d5b1ebf2b4e5979e252264085f875eb9849eefeb718d"),
    (9,  "UNI",     "0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984", "0x78d185a741d07edb3412b09008b7c5cfb9bbbd7d568bf00ba737b456ba171501"),
    (10, "CAKE",    "0x152649eA73beAb28c5b49B26eb48f7EAD6d4c898", "0x2356af9529a1064d41e32d617e2ce1dca5733afa901daba9e2b68dee5d53ecf9"),
    (11, "LIT",     "0x232CE3bd40fCd6f80f3d55A522d03f25Df784Ee2", "0xc0c83f00c39165892d55dcd17ade2191e289697e2ac132d9ab721e20834e2a9e"),
    (12, "FLUID",   "0x6f40d4A6237C257fff2dB00FA0510DeEECd303eb", "0x47d462d8bac4c29b6ae1792029b9b92c8adea12ed22155bfc22f481287f1e349"),
    (13, "CRV",     "0x4B1E80cAC91e2216EEb63e29B957eB91Ae9C2Be8", "0xa19d04ac696c7a6616d291c7e5d1377cc8be437c327b75adb5dc1bad745fcae8"),
    (14, "PENDLE",  "0x808507121B80c02388fAd14726482e061B8da827", "0x9a4df90b25497f66b1afb012467e316e801ca3d839456db028892fe8c70c8016"),
    (15, "POL",     "0x455e53CBB86018Ac2B8092FdCd39d8444aFFC3F6", "0xffd11c5a1cfd42f80afb2df4d9f264c15f956d68153335374ec10722edd70472"),
    (16, "ARB",     "0xB50721BCf8d664c30412Cfbc6cf7a15145234ad1", "0x3fa4252848f9f0a1480be62745a4629d9eb1322aebab8a791e344b3b9c1adcf5"),
    (17, "STRK",    "0xCa14007Eff0dB1f8135f4C25B34De49AB0d42766", "0x6a182399ff70ccf3e06024898942028204125a819e519a335ffa4579e66cd870"),
    (18, "IMX",     "0xF57e7e7C23978C3cAEC3C3548E3D615c346e79fF", "0x941320a8989414874de5aa2fc340a75d5ed91fdff1613dd55f83844d52ea63a2"),
    (19, "LINK",    "0x514910771AF9Ca656af840dff83E8264EcF986CA", "0x8ac0c70fff57e9aefdf5edf44b51d62c2d433653cbb2cf5cc06bb115af04d221"),
    (20, "ZRO",     "0x6985884C4392D348587B19cb9eAAf157F13271cd", "0x3bd860bea28bf982fa06bcf358118064bb114086cc03993bd76197eaab0b8018"),
    (21, "NEAR",    "0x77E06c9eCCf2E797fd462A92B6D7642EF85b0A44", "0xc415de8d2eba7db216527dff4b60e8f3a5311c740dadb233e13e12547e226750"),
    (22, "ATH",     "0xbe0Ed4138121EcFC5c0E56B40517da27E6c5226B", "0xf6b551a947e7990089e2d5149b1e44b369fcc6ad3627cb822362a2b19d24ad4a"),
    (23, "RENDER",  "0x44ff8620b8cA30902395A7bD3F2407e1A091BF73", "0x3d4a2bd9535be6ce8059d75eadeba507b043257321aa544717c56fa19b49e35d"),
    (24, "TAO",     "0x85F17Cf997934a597031b2E18a9aB6ebD4B9f6a4", "0x410f41de235f2db824e562ea7ab2d3d3d4ff048316c61d629c0b93f58584e1af"),
    (25, "ONDO",    "0xfAbA6f8e4a5E8Ab82F62fe7C39859FA577269BE3", "0xd40472610abe56d36d065a0cf889fc8f1dd9f3b7f2a478231a5fc6df07ea5ce3"),
    (26, "CRCLon",  "0x3632DEa96A953C11dac2f00b4A05a32CD1063fAE", "0x92b8527aabe59ea2b12230f7b532769b133ffb118dfbd48ff676f14b273f1365"),
    (27, "SPYon",   "0xFeDC5f4a6c38211c1338aa411018DFAf26612c08", "0x19e09bb805456ada3979a7d1cbb4b6d63babc3a0f8e8a9509f68afa5c4c11cd5"),
    (28, "NVDAon",  "0x2D1F7226Bd1F780AF6B9A49DCC0aE00E8Df4bDEE", "0xb1073854ed24cbc755dc527418f52b7d271f6cc967bbf8d8129112b18860a593"),
    (29, "XAUT",    "0x68749665FF8D2d112Fa859AA293F07A622782F38", "0x44465e17d2e9d390e70c999d5a11fda4f092847fcd2e3e5aa089d96c98a30e67"),
    (30, "WBTC",    "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599", "0xc9d8b075a5c69303365ae23633d4e085199bf5c520a3b90fed1322a0342ffc33"),
    (31, "ETH",     ETH_BASE,                                       "0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace"),
    (32, "BNB",     "0xB8c77482e45F1F44dE1745F52C74426C631bDD52", "0x2f95862b045670cd22bee3114c39763a4a08beeb663b145d283c31d7d1101c4f"),
    (33, "TRX",     "0x50327c6c5a14DCaDE707ABad2E27eB517df87AB5", "0x67aed5a24fdad045475e7195c98a98aea119c763f272d4523f5bac93a4f33c2b"),
    (34, "WZEC",    "0x4A64515E5E1d1073e83f30cB97BEd20400b66E10", "0xbe9b59d178f0d6a97ab4c343bff2aa69caa1eaae3e9048a65788c529b125bb24"),
    # User-added rows below. Note: script declares `new address[](35)` so these
    # 6 entries would revert on deploy — they are NOT on-chain.
    (35, "ETHx*",   "0xFe0c30065B384F05761f15d0CC899D4F9F9Cc0eB", "0xb27578a9654246cb0a2950842b92330e9ace141c52b63829cc72d5c45a5a595a"),
    (36, "IOTX",    "0x6fB3e0A217407EFFf7Ca062D46c26E5d60a14d69", "0xa83103141916013b5679001e273281303a6c05f4cebd94da00a785bd74d1e6d8"),
    (37, "WFIL",    "0x6e1A19F235bE7ED8E3369eF73b196C07257494DE", "0x150ac9b959aee0051e4091f0ef5216d941f590e1c5e7f91cf7635b5c11628c0e"),
    (38, "COINon",  "0xF042cfa86cf1D598a75Bdb55c3507a1F39f9493b", "0x42ded7a3ed036606ab22ece1c942f6f9245a67f6f4ec27cfad5974d45fe9d6b6"),
    (39, "QQQon",   "0x0e397938C1Aa0680954093495B70A9F5e2249aBa", "0x9695e2b96ea7b3859da9ed25b7a46a920a776e2fdae19a7bcfdf2b219230452d"),
    (40, "GOOGLon", "0xbA47214eDd2bb43099611b208f75E4b42FDcfEDc", "0x07d24bb76843496a45bce0add8b51555f2ea02098cb04f4c6d61f7b5720836b4"),
]


def cast_call(target, sig, *args):
    cmd = ["cast", "call", target, sig, *args, "--rpc-url", RPC]
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
    except subprocess.TimeoutExpired:
        return None, "TIMEOUT"
    if out.returncode != 0:
        err = (out.stderr or out.stdout).strip().splitlines()
        return None, "REVERT: " + (err[-1] if err else "unknown")
    return out.stdout.strip(), None


def fmt_price(raw_int, expo):
    if raw_int is None:
        return None
    if expo is None:
        return str(raw_int)
    return f"{Decimal(raw_int) * (Decimal(10) ** expo):,.4f}"


def hermes_batch(feed_ids):
    # Hermes 403s urllib's default UA; spoof curl. Chunk in <=20 to keep URL short.
    out = {}
    HEAD = {"User-Agent": "curl/8.0"}
    CHUNK = 20
    for i in range(0, len(feed_ids), CHUNK):
        chunk = feed_ids[i:i + CHUNK]
        qs = "&".join(f"ids%5B%5D={fid.lower().removeprefix('0x')}" for fid in chunk)
        url = f"https://hermes.pyth.network/v2/updates/price/latest?{qs}&parsed=true"
        req = urllib.request.Request(url, headers=HEAD)
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                data = json.loads(resp.read())
        except Exception as e:
            for fid in chunk:
                out[fid.lower()] = ("ERR", f"hermes fetch failed: {type(e).__name__}: {e}")
            continue
        for item in data.get("parsed", []):
            fid = "0x" + item["id"].lower()
            p = item.get("price", {})
            try:
                usd = fmt_price(int(p["price"]), int(p["expo"]))
                pub = p.get("publish_time")
                out[fid] = (usd, pub)
            except Exception as e:
                out[fid] = ("ERR", f"parse fail: {e}")
        for fid in chunk:
            if fid.lower() not in out:
                out[fid.lower()] = ("MISSING", "feed not in Hermes response")
    return out


def parse_unsafe_output(stdout):
    # cast call output formats as: 211984456248 [2.119e11]\n179043751 [1.79e8]\n-8\n1779359149 [1.779e9]
    lines = [l.strip() for l in stdout.splitlines() if l.strip()]
    if len(lines) < 4:
        return None, None, None, None
    def first_int(s):
        return int(s.split()[0])
    return first_int(lines[0]), first_int(lines[1]), first_int(lines[2]), first_int(lines[3])


def main():
    # Batch Hermes (single request for all feedIds).
    feed_ids = [r[3] for r in ROWS]
    hermes = hermes_batch(feed_ids)

    rows_out = []
    for idx, sym, token, feed in ROWS:
        # 1) oracle.priceFeedId(token)
        onchain, err = cast_call(ORACLE, "priceFeedId(address)(bytes32)", token)
        if err:
            oracle_status = f"ERR ({err})"
        else:
            if onchain.lower() == feed.lower():
                oracle_status = "YES"
            elif int(onchain, 16) == 0:
                oracle_status = "MISSING"
            else:
                oracle_status = f"MISMATCH ({onchain})"

        # 2) Hermes
        hermes_price, hermes_pubtime = hermes.get(feed.lower(), ("MISSING", "not requested"))

        # 3) PYTH.getPriceUnsafe(feedId)
        unsafe_out, perr = cast_call(PYTH, "getPriceUnsafe(bytes32)(int64,uint64,int32,uint256)", feed)
        if perr:
            pyth_price = f"ERR ({perr})"
            pyth_pubtime = "-"
        else:
            price, conf, expo, pubtime = parse_unsafe_output(unsafe_out)
            if price is None:
                pyth_price = "PARSE_ERR"
                pyth_pubtime = "-"
            else:
                pyth_price = fmt_price(price, expo)
                pyth_pubtime = str(pubtime)

        rows_out.append((idx, sym, token, feed, oracle_status, hermes_price, hermes_pubtime, pyth_price, pyth_pubtime))
        print(f"[{idx:>2}] {sym:8} oracle={oracle_status:<70} hermes={str(hermes_price):<14} pyth={pyth_price:<14} pubtime={pyth_pubtime}")

    # Markdown table
    md = []
    md.append("| # | Symbol | Token | feedId (script) | Oracle has it? | Hermes USD | PYTH.getPriceUnsafe USD | PYTH publishTime |")
    md.append("|---|---|---|---|---|---|---|---|")
    for idx, sym, token, feed, ok, hp, _hpt, pp, pt in rows_out:
        feed_short = f"`{feed[:10]}…{feed[-6:]}`"
        token_short = f"`{token[:10]}…{token[-4:]}`"
        md.append(f"| {idx} | {sym} | {token_short} | {feed_short} | {ok} | {hp} | {pp} | {pt} |")
    md_text = "\n".join(md)

    with open("/tmp/task6_verify/report.md", "w") as f:
        f.write(md_text + "\n")
    print("\n--- Markdown report written to /tmp/task6_verify/report.md ---")


if __name__ == "__main__":
    main()
