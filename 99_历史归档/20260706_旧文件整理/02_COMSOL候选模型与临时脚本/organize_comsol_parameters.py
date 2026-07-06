import argparse
import json
import re
from collections import OrderedDict

import mph


GROUPS = OrderedDict(
    [
        (
            "par1",
            {
                "label": "00_Global_constants_and_case",
                "title": "00 全局常数与工况控制",
                "patterns": [
                    r"^case_",
                    r"^N_",
                    r"^F_const$",
                    r"^R_const$",
                    r"^eps_rh$",
                    r"^eps_s$",
                    r"^eps_Q$",
                    r"^T0$",
                    r"^p0$",
                    r"^tiny_",
                ],
            },
        ),
        (
            "par_geometry",
            {
                "label": "01_Geometry_and_structure",
                "title": "01 几何与结构尺寸",
                "patterns": [
                    r"^L_(cell|CH|GDL|MPL|PEM|CL)",
                    r"^W_(cell|CH|GDL|MPL|PEM|CL)",
                    r"^H_(cell|CH|GDL|MPL|PEM|CL)",
                    r"^A_",
                    r"^t_",
                    r"^d_",
                    r"^r_",
                ],
            },
        ),
        (
            "par_operating",
            {
                "label": "02_Operating_conditions_and_boundaries",
                "title": "02 工况与边界条件",
                "patterns": [
                    r"^I_",
                    r"^i_",
                    r"^j_",
                    r"^V_",
                    r"^T_",
                    r"^W_",
                    r"^U_",
                    r"^p_",
                    r"^RH_",
                    r"^phi_",
                    r"^x_",
                    r"^Y_",
                    r"^(an|ca|a|c)_",
                    r"^m_dot",
                    r"^n_dot",
                    r"^Q_",
                    r"^u_",
                    r"^stoich",
                    r"^lambda",
                    r"^lam_",
                    r"^EGR",
                    r"^alpha_cyc",
                ],
            },
        ),
        (
            "par_transport",
            {
                "label": "03_Transport_and_material_properties",
                "title": "03 传质与材料物性",
                "patterns": [
                    r"^D_",
                    r"^mu_",
                    r"^rho_",
                    r"^cp_",
                    r"^Cp_",
                    r"^k_",
                    r"^K_",
                    r"^M_",
                    r"^sigma_",
                    r"^sigmal_",
                    r"^kappa_",
                    r"^S_",
                    r"^s_",
                    r"^tau_",
                    r"^perm",
                    r"^epsg_",
                    r"^epss_",
                    r"^EW$",
                ],
            },
        ),
        (
            "par_echem",
            {
                "label": "04_Electrochemical_performance",
                "title": "04 电化学性能与极化拟合",
                "patterns": [
                    r"^E_",
                    r"^eta_(?!heat)",
                    r"^alpha",
                    r"^i0",
                    r"^i_0",
                    r"^j0",
                    r"^j_0",
                    r"^a_v",
                    r"^A_v",
                    r"^Av_",
                    r"^R_ohm",
                    r"^R_mem",
                    r"^R_contact",
                    r"^R_contact_",
                    r"^theta",
                    r"^b_",
                    r"^crossover",
                    r"^V_loss",
                ],
            },
        ),
        (
            "par_thermal",
            {
                "label": "05_Thermal_and_cooling",
                "title": "05 热管理与冷却",
                "patterns": [
                    r"^h_",
                    r"^UA_",
                    r"^Cth_",
                    r"^Q_.*heat",
                    r"^q_",
                    r"^T_cool",
                    r"^m_dot_cool",
                    r"^cp_cool",
                    r"^Cp_cool",
                    r"^rho_cool",
                    r"^eta_heat",
                    r"^k_thermal",
                ],
            },
        ),
        (
            "par_fit",
            {
                "label": "06_Calibration_controls",
                "title": "06 参数辨识控制量",
                "patterns": [
                    r"^fit_",
                    r"^cal_",
                    r"^scale_",
                    r"^mult_",
                    r"^corr_",
                    r"^offset_",
                    r"^gain_",
                ],
            },
        ),
        (
            "par_uncategorized",
            {
                "label": "99_Uncategorized_review_required",
                "title": "99 未分类待复核",
                "patterns": [],
            },
        ),
    ]
)


def java_tags(collection):
    try:
        return [str(x) for x in collection.tags()]
    except Exception:
        return []


def safe_label(entity):
    try:
        return str(entity.label())
    except Exception:
        return ""


def get_param_node(jmodel, tag):
    if tag in ("", "par1", "param", "root"):
        try:
            return jmodel.param()
        except Exception:
            return jmodel.param("par1")
    return jmodel.param(tag)


def param_varnames(node):
    try:
        return [str(x) for x in node.varnames()]
    except Exception:
        try:
            return [str(x) for x in node.tags()]
        except Exception:
            return []


def param_get(node, name):
    try:
        return str(node.get(name))
    except Exception:
        return ""


def param_descr(node, name):
    for method in ("descr", "description"):
        try:
            return str(getattr(node, method)(name))
        except Exception:
            pass
    return ""


def set_param_descr(node, name, description):
    if not description:
        return
    for method in ("descr", "description"):
        try:
            getattr(node, method)(name, description)
            return
        except Exception:
            pass


def remove_param(node, name):
    for method in ("remove", "clear"):
        try:
            getattr(node, method)(name)
            return True
        except Exception:
            pass
    return False


def remove_from_non_target_groups(jmodel, name, target_tag):
    tags = list(OrderedDict.fromkeys(["par1"] + java_tags(jmodel.param()) + list(GROUPS.keys())))
    for tag in tags:
        if tag == target_tag:
            continue
        try:
            node = get_param_node(jmodel, tag)
        except Exception:
            continue
        if name in param_varnames(node):
            remove_param(node, name)


def classify(name):
    for tag, info in GROUPS.items():
        if tag == "par_uncategorized":
            continue
        for pattern in info["patterns"]:
            if re.search(pattern, name):
                return tag
    return "par_uncategorized"


def connect(port):
    client = mph.Client(host="127.0.0.1", port=port)
    models = client.models()
    if not models:
        raise RuntimeError(f"No COMSOL model is loaded on 127.0.0.1:{port}.")
    return client, models[0]


def inventory(jmodel):
    result = OrderedDict()
    tags = list(OrderedDict.fromkeys(["par1"] + java_tags(jmodel.param()) + list(GROUPS.keys())))
    for tag in tags:
        try:
            node = get_param_node(jmodel, tag)
        except Exception:
            continue
        entries = []
        for name in param_varnames(node):
            entries.append(
                {
                    "name": name,
                    "expr": param_get(node, name),
                    "descr": param_descr(node, name),
                }
            )
        result[tag] = {"label": safe_label(node), "entries": entries}
    return result


def ensure_group(jmodel, tag, label):
    if tag == "par1":
        node = get_param_node(jmodel, tag)
    else:
        try:
            node = get_param_node(jmodel, tag)
        except Exception:
            try:
                jmodel.param().create(tag)
            except Exception:
                pass
            node = get_param_node(jmodel, tag)
    try:
        node.label(label)
    except Exception:
        pass
    return node


def organize(jmodel, dry_run):
    before = inventory(jmodel)
    all_entries = OrderedDict()
    for source_tag, node_info in before.items():
        for entry in node_info["entries"]:
            name = entry["name"]
            if name not in all_entries:
                all_entries[name] = dict(entry, source_tag=source_tag, target_tag=classify(name))

    grouped = OrderedDict((tag, []) for tag in GROUPS)
    for entry in all_entries.values():
        grouped[entry["target_tag"]].append(entry)

    summary = {
        "dry_run": dry_run,
        "before_nodes": {tag: {"label": item["label"], "count": len(item["entries"])} for tag, item in before.items()},
        "target_groups": {tag: {"label": GROUPS[tag]["label"], "count": len(entries)} for tag, entries in grouped.items()},
        "moves": [
            {
                "name": entry["name"],
                "from": entry["source_tag"],
                "to": entry["target_tag"],
                "expr": entry["expr"],
                "descr": entry["descr"],
            }
            for entries in grouped.values()
            for entry in entries
        ],
    }

    if dry_run:
        return summary

    for tag, info in GROUPS.items():
        ensure_group(jmodel, tag, info["label"])

    for entry in all_entries.values():
        remove_from_non_target_groups(jmodel, entry["name"], entry["target_tag"])

    for tag, entries in grouped.items():
        node = get_param_node(jmodel, tag)
        for entry in entries:
            node.set(entry["name"], entry["expr"])
            set_param_descr(node, entry["name"], entry["descr"])

    after = inventory(jmodel)
    summary["after_nodes"] = {tag: {"label": item["label"], "count": len(item["entries"])} for tag, item in after.items()}
    summary["verification"] = verify_key_parameters(after)
    return summary


def verify_key_parameters(inv):
    checks = OrderedDict(
        [
            ("case_idx", "par1"),
            ("L_PEM", "par_geometry"),
            ("p_c_in", "par_operating"),
            ("K_CH_c", "par_transport"),
            ("UA_cool_stack", "par_thermal"),
            ("i0_ref_c", "par_echem"),
            ("alpha_a_c", "par_echem"),
            ("Av_c", "par_echem"),
            ("R_contact_c_area", "par_echem"),
            ("fit_scale_V", "par_fit"),
        ]
    )
    locations = {}
    for name, expected in checks.items():
        found = []
        for tag, node_info in inv.items():
            if tag == "par1":
                continue
            names = {entry["name"] for entry in node_info["entries"]}
            if name in names:
                found.append(tag)
        locations[name] = {
            "expected": expected,
            "found_groups": found,
            "pass": expected == "par1" or found == [expected],
        }
    return locations


def main():
    parser = argparse.ArgumentParser(description="Organize COMSOL global Parameters nodes for the active server model.")
    parser.add_argument("--port", type=int, default=2036)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--summary-only", action="store_true")
    args = parser.parse_args()

    client, model = connect(args.port)
    try:
        summary = organize(model.java, args.dry_run)
        summary["model_name"] = model.name()
        summary["model_file"] = str(model.file())
        if args.summary_only:
            summary = {
                "dry_run": summary["dry_run"],
                "before_nodes": summary["before_nodes"],
                "target_groups": summary["target_groups"],
                "after_nodes": summary.get("after_nodes", {}),
                "verification": summary.get("verification", {}),
                "model_name": summary["model_name"],
                "model_file": summary["model_file"],
            }
        print(json.dumps(summary, ensure_ascii=False, indent=2))
    finally:
        client.disconnect()


if __name__ == "__main__":
    main()
