import argparse
import json
from pathlib import Path

import mph


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


def safe_get_string(entity, key):
    try:
        return str(entity.getString(key))
    except Exception:
        return ""


def safe_properties(entity):
    try:
        return [str(x) for x in entity.properties()]
    except Exception:
        return []


def connect_model(port: int):
    client = mph.Client(host="127.0.0.1", port=port)
    models = client.models()
    if not models:
        raise RuntimeError(f"No model loaded on server {port}")
    return client, models[0]


def inspect_source(port: int):
    client, model = connect_model(port)
    jm = model.java

    inventory = {
        "server_port": port,
        "model_name": model.name(),
        "model_file": str(model.file()),
        "parameters": model.parameters(),
        "components": [],
        "global_variables": [],
        "global_functions": [],
        "studies": [],
        "datasets": [],
    }

    for tag in java_tags(jm.variable()):
        var = jm.variable(tag)
        props = safe_properties(var)
        entries = {}
        try:
            for name in [str(x) for x in var.varnames()]:
                try:
                    entries[name] = str(var.get(name))
                except Exception:
                    pass
        except Exception:
            pass
        inventory["global_variables"].append(
            {"tag": tag, "label": safe_label(var), "properties": props, "entries": entries}
        )

    for tag in java_tags(jm.func()):
        func = jm.func(tag)
        inventory["global_functions"].append(
            {
                "tag": tag,
                "label": safe_label(func),
                "feature_type": safe_get_string(func, "funcname"),
                "properties": safe_properties(func),
            }
        )

    for tag in java_tags(jm.study()):
        study = jm.study(tag)
        inventory["studies"].append(
            {"tag": tag, "label": safe_label(study), "features": java_tags(study.feature())}
        )

    try:
        ds = jm.result().dataset()
        for tag in java_tags(ds):
            inventory["datasets"].append({"tag": tag, "label": safe_label(ds(tag))})
    except Exception:
        pass

    for comp_tag in java_tags(jm.component()):
        comp = jm.component(comp_tag)
        comp_info = {
            "tag": comp_tag,
            "label": safe_label(comp),
            "geom": [],
            "variables": [],
            "physics": [],
            "materials": [],
        }

        for geom_tag in java_tags(comp.geom()):
            geom = comp.geom(geom_tag)
            features = []
            for feat_tag in java_tags(geom.feature()):
                feat = geom.feature(feat_tag)
                props = safe_properties(feat)
                feature = {
                    "tag": feat_tag,
                    "label": safe_label(feat),
                    "type": "",
                    "properties": {},
                }
                try:
                    feature["type"] = str(feat.getType())
                except Exception:
                    pass
                for prop in props:
                    if prop in ("x", "y", "lx", "ly", "pos", "size", "base", "action", "createpairs", "imprint", "selresult", "contributeto", "createselection", "axisymmetric"):
                        try:
                            feature["properties"][prop] = str(feat.getString(prop))
                        except Exception:
                            try:
                                feature["properties"][prop] = str(feat.getDouble(prop))
                            except Exception:
                                try:
                                    feature["properties"][prop] = str(feat.getBoolean(prop))
                                except Exception:
                                    pass
                features.append(feature)
            comp_info["geom"].append(
                {"tag": geom_tag, "label": safe_label(geom), "features": features}
            )

        for var_tag in java_tags(comp.variable()):
            var = comp.variable(var_tag)
            props = safe_properties(var)
            entries = {}
            try:
                for name in [str(x) for x in var.varnames()]:
                    try:
                        entries[name] = str(var.get(name))
                    except Exception:
                        pass
            except Exception:
                pass
            comp_info["variables"].append(
                {"tag": var_tag, "label": safe_label(var), "properties": props, "entries": entries}
            )

        for phys_tag in java_tags(comp.physics()):
            phys = comp.physics(phys_tag)
            features = []
            for feat_tag in java_tags(phys.feature()):
                feat = phys.feature(feat_tag)
                feature = {
                    "tag": feat_tag,
                    "label": safe_label(feat),
                    "type": "",
                    "properties": {},
                }
                try:
                    feature["type"] = str(feat.getType())
                except Exception:
                    pass
                for prop in ("dim", "shapeorder", "order_electricpotential", "order_protonicpotential"):
                    try:
                        feature["properties"][prop] = str(feat.get(prop))
                    except Exception:
                        pass
                features.append(feature)
            comp_info["physics"].append(
                {"tag": phys_tag, "label": safe_label(phys), "type": str(phys.getType()), "features": features}
            )

        for mat_tag in java_tags(comp.material()):
            mat = comp.material(mat_tag)
            comp_info["materials"].append({"tag": mat_tag, "label": safe_label(mat)})

        inventory["components"].append(comp_info)

    client.disconnect()
    return inventory


def clone_to_target(source: dict, target_port: int):
    client, model = connect_model(target_port)
    jm = model.java

    result = {
        "server_port": target_port,
        "model_name": model.name(),
        "actions": [],
    }

    existing_params = set(model.parameters().keys())
    for name, expr in source["parameters"].items():
        if name not in existing_params:
            model.parameter(name, expr)
            result["actions"].append(f"param:create:{name}")

    source_file = source["model_file"]

    for var in source["global_variables"]:
        tag = var["tag"]
        if tag not in java_tags(jm.variable()):
            try:
                jm.variable().create(tag)
                result["actions"].append(f"global_variable:create:{tag}")
            except Exception as exc:
                result["actions"].append(f"global_variable:skip:{tag}:{exc}")
        try:
            jm.variable(tag).label(var["label"])
        except Exception:
            pass
        for name, expr in var["entries"].items():
            try:
                jm.variable(tag).set(name, expr)
                result["actions"].append(f"global_variable:set:{tag}/{name}")
            except Exception as exc:
                result["actions"].append(f"global_variable:setskip:{tag}/{name}:{exc}")

    source_func_tags = [item["tag"] for item in source["global_functions"]]
    if source_func_tags:
        existing_func_tags = set(java_tags(jm.func()))
        for tag in source_func_tags:
            if tag in existing_func_tags:
                try:
                    jm.func().remove(tag)
                    result["actions"].append(f"func:remove:{tag}")
                except Exception as exc:
                    result["actions"].append(f"func:removeskip:{tag}:{exc}")
        try:
            jm.func().insert(source_file, source_func_tags, [])
            result["actions"].append(f"func:insert:{len(source_func_tags)}")
        except Exception as exc:
            result["actions"].append(f"func:insertskip:{exc}")

    source_comp_tags = [item["tag"] for item in source["components"]]
    if source_comp_tags:
        existing_comp_tags = set(java_tags(jm.component()))
        for tag in source_comp_tags:
            if tag in existing_comp_tags:
                try:
                    jm.component().remove(tag)
                    result["actions"].append(f"component:remove:{tag}")
                except Exception as exc:
                    result["actions"].append(f"component:removeskip:{tag}:{exc}")
        try:
            jm.component().insert(source_file, source_comp_tags, [])
            result["actions"].append(f"component:insert:{len(source_comp_tags)}")
        except Exception as exc:
            result["actions"].append(f"component:insertskip:{exc}")

    try:
        client.disconnect()
    except Exception:
        pass
    return result


def verify_target(port: int):
    return inspect_source(port)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-port", type=int, default=2036)
    parser.add_argument("--target-port", type=int, default=2038)
    parser.add_argument("--inventory-json", type=str, default="")
    parser.add_argument("--mode", choices=["inspect", "clone", "verify"], required=True)
    args = parser.parse_args()

    if args.mode == "inspect":
        data = inspect_source(args.source_port)
        print(json.dumps(data, ensure_ascii=False, indent=2))
        return

    if not args.inventory_json:
        raise SystemExit("--inventory-json is required for clone/verify mode")

    source = json.loads(Path(args.inventory_json).read_text(encoding="utf-8"))

    if args.mode == "clone":
        result = clone_to_target(source, args.target_port)
        print(json.dumps(result, ensure_ascii=False, indent=2))
    elif args.mode == "verify":
        data = verify_target(args.target_port)
        print(json.dumps(data, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
