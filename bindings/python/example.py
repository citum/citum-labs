import os
import sys
from citum import CitumProcessor, CitumError

def run_demo():
    # Use existing example assets if available
    style_path = os.path.join(os.path.dirname(__file__), "..", "latex", "citum-example.tex") # Styles are often embedded in tex for labs
    bib_path = os.path.join(os.path.dirname(__file__), "..", "latex", "example-refs.yaml")
    
    # Minimal inline style for the demo if the above isn't a pure style file
    style_yaml = """
citation:
  layout:
    - [prefix: "(", suffix: ")"]
    - [item: author, suffix: ", "]
    - [item: year]
bibliography:
  layout:
    - [item: author, suffix: ". "]
    - [item: title, font-style: italic, suffix: ". "]
    - [item: year, suffix: "."]
"""

    if not os.path.exists(bib_path):
        print(f"Error: Could not find bibliography at {bib_path}")
        return

    with open(bib_path, "r") as f:
        bib_yaml = f.read()

    try:
        print("--- Citum Python Binding Demo ---")
        
        # Initialize
        proc = CitumProcessor.from_yaml(style_yaml, bib_yaml)
        print(f"Engine Version: {proc.version()}")
        
        # Render single citation
        print("\nSingle Citation (Plain):")
        print(proc.render_citation("darcus2024", format="plain"))
        
        # Render with options
        print("\nCitation with Locator (HTML):")
        cite_opts = {
            "items": [
                {"id": "darcus2024", "label": "page", "locator": "42"}
            ]
        }
        print(proc.render_citation(cite_opts, format="html"))
        
        # Batch render
        print("\nBatch Render (Plain):")
        batch = [
            {"items": [{"id": "darcus2024"}]},
            {"items": [{"id": "doe2023"}]} # Assuming this exists or will show error
        ]
        results = proc.render_citations_batch(batch, format="plain")
        for i, res in enumerate(results):
            print(f"[{i}] {res}")
            
        # Bibliography
        print("\nBibliography (Plain):")
        print(proc.render_bibliography(format="plain"))

    except ImportError as e:
        print(f"Setup Error: {e}")
        print("\nNote: You need to have libcitum_processor available.")
        print("Set CITUM_LIB_PATH=/path/to/libcitum_processor.dylib (or .so/.dll)")
    except CitumError as e:
        print(f"Engine Error: {e}")
    except Exception as e:
        print(f"Unexpected Error: {e}")

if __name__ == "__main__":
    # Add current dir to path to find citum.py
    sys.path.append(os.path.dirname(__file__))
    run_demo()
