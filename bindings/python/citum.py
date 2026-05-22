import os
import json
import ctypes
from typing import Optional, Union, Dict, Any, List

class CitumError(Exception):
    """Exception raised for errors in the Citum engine."""
    pass

class CitumProcessor:
    """
    A Python wrapper for the Citum citation processor.
    """

    def __init__(self, lib_path: Optional[str] = None):
        self._lib = self._load_library(lib_path)
        self._setup_ffi()
        self._ptr = None

    def _load_library(self, lib_path: Optional[str]) -> ctypes.CDLL:
        if not lib_path:
            lib_path = os.environ.get("CITUM_LIB_PATH")
        
        if lib_path:
            return ctypes.CDLL(lib_path)

        # Default platform-specific names
        import platform
        system = platform.system()
        if system == "Darwin":
            name = "libcitum_processor.dylib"
        elif system == "Windows":
            name = "citum_engine.dll"
        else:
            name = "libcitum_processor.so"

        # Try current directory first, then system paths
        try:
            return ctypes.CDLL(os.path.join(os.getcwd(), name))
        except OSError:
            try:
                return ctypes.CDLL(name)
            except OSError as e:
                raise ImportError(
                    f"Could not load Citum library '{name}'. "
                    "Ensure it is in your library path or set CITUM_LIB_PATH."
                ) from e

    def _setup_ffi(self):
        # void* citum_processor_new(const char* style_json, const char* bib_json)
        self._lib.citum_processor_new.argtypes = [ctypes.c_char_p, ctypes.c_char_p]
        self._lib.citum_processor_new.restype = ctypes.c_void_p

        # void* citum_processor_new_with_locale(const char* style_json, const char* bib_json, const char* locale_json)
        self._lib.citum_processor_new_with_locale.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_char_p]
        self._lib.citum_processor_new_with_locale.restype = ctypes.c_void_p

        # void* citum_processor_new_from_yaml(const char* style_yaml, const char* bib_yaml)
        self._lib.citum_processor_new_from_yaml.argtypes = [ctypes.c_char_p, ctypes.c_char_p]
        self._lib.citum_processor_new_from_yaml.restype = ctypes.c_void_p

        # void* citum_processor_new_with_locale_from_yaml(const char* style_yaml, const char* bib_yaml, const char* locale_yaml)
        self._lib.citum_processor_new_with_locale_from_yaml.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_char_p]
        self._lib.citum_processor_new_with_locale_from_yaml.restype = ctypes.c_void_p

        # void citum_processor_free(void* processor)
        self._lib.citum_processor_free.argtypes = [ctypes.c_void_p]
        self._lib.citum_processor_free.restype = None

        # char* citum_get_last_error()
        self._lib.citum_get_last_error.argtypes = []
        self._lib.citum_get_last_error.restype = ctypes.c_void_p

        # char* citum_version()
        self._lib.citum_version.argtypes = []
        self._lib.citum_version.restype = ctypes.c_void_p

        # char* citum_render_citation_latex(void* processor, const char* cite_json)
        self._lib.citum_render_citation_latex.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
        self._lib.citum_render_citation_latex.restype = ctypes.c_void_p

        # Other formats follow the same pattern
        formats = ["html", "plain", "djot", "typst"]
        for fmt in formats:
            func = getattr(self._lib, f"citum_render_citation_{fmt}")
            func.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
            func.restype = ctypes.c_void_p

            func_bib = getattr(self._lib, f"citum_render_bibliography_{fmt}")
            func_bib.argtypes = [ctypes.c_void_p]
            func_bib.restype = ctypes.c_void_p

        self._lib.citum_render_bibliography_latex.argtypes = [ctypes.c_void_p]
        self._lib.citum_render_bibliography_latex.restype = ctypes.c_void_p

        # char* citum_render_citations_json(void* processor, const char* citations_json, const char* format)
        self._lib.citum_render_citations_json.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p]
        self._lib.citum_render_citations_json.restype = ctypes.c_void_p

        # void citum_string_free(char* s)
        self._lib.citum_string_free.argtypes = [ctypes.c_void_p]
        self._lib.citum_string_free.restype = None

    def _to_python_string(self, c_ptr: ctypes.c_void_p) -> Optional[str]:
        if not c_ptr:
            return None
        s = ctypes.string_at(c_ptr).decode('utf-8')
        self._lib.citum_string_free(c_ptr)
        return s

    def get_last_error(self) -> Optional[str]:
        return self._to_python_string(self._lib.citum_get_last_error())

    def version(self) -> str:
        return self._to_python_string(self._lib.citum_version()) or "unknown"

    @classmethod
    def from_json(cls, style_json: str, bib_json: str, locale_json: Optional[str] = None, lib_path: Optional[str] = None):
        instance = cls(lib_path)
        if locale_json:
            instance._ptr = instance._lib.citum_processor_new_with_locale(
                style_json.encode('utf-8'), 
                bib_json.encode('utf-8'), 
                locale_json.encode('utf-8')
            )
        else:
            instance._ptr = instance._lib.citum_processor_new(
                style_json.encode('utf-8'), 
                bib_json.encode('utf-8')
            )
        
        if not instance._ptr:
            err = instance.get_last_error()
            raise CitumError(f"Failed to initialize processor: {err}")
        return instance

    @classmethod
    def from_yaml(cls, style_yaml: str, bib_yaml: str, locale_yaml: Optional[str] = None, lib_path: Optional[str] = None):
        instance = cls(lib_path)
        if locale_yaml:
            instance._ptr = instance._lib.citum_processor_new_with_locale_from_yaml(
                style_yaml.encode('utf-8'), 
                bib_yaml.encode('utf-8'), 
                locale_yaml.encode('utf-8')
            )
        else:
            instance._ptr = instance._lib.citum_processor_new_from_yaml(
                style_yaml.encode('utf-8'), 
                bib_yaml.encode('utf-8')
            )
        
        if not instance._ptr:
            err = instance.get_last_error()
            raise CitumError(f"Failed to initialize processor from YAML: {err}")
        return instance

    def __del__(self):
        if hasattr(self, '_ptr') and self._ptr:
            self._lib.citum_processor_free(self._ptr)
            self._ptr = None

    def render_citation(self, cite_opts: Union[str, Dict[str, Any]], format: str = "plain") -> str:
        """
        Render a citation. cite_opts can be a citation ID string or a dict of options.
        """
        if isinstance(cite_opts, str):
            cite_data = {"items": [{"id": cite_opts}]}
        else:
            cite_data = cite_opts

        cite_json = json.dumps(cite_data).encode('utf-8')
        
        func_name = f"citum_render_citation_{format}"
        func = getattr(self._lib, func_name, None)
        if not func:
            raise ValueError(f"Unsupported format: {format}")

        result_ptr = func(self._ptr, cite_json)
        if not result_ptr:
            err = self.get_last_error()
            return f"[citum render error: {err or 'unknown'}]"
        
        return self._to_python_string(result_ptr)

    def render_bibliography(self, format: str = "plain") -> str:
        """
        Render the bibliography.
        """
        func_name = f"citum_render_bibliography_{format}"
        func = getattr(self._lib, func_name, None)
        if not func:
            raise ValueError(f"Unsupported format: {format}")

        result_ptr = func(self._ptr)
        if not result_ptr:
            err = self.get_last_error()
            return f"[citum bibliography error: {err or 'unknown'}]"
        
        return self._to_python_string(result_ptr)

    def render_citations_batch(self, citations: List[Dict[str, Any]], format: str = "plain") -> List[str]:
        """
        Render a batch of citations.
        """
        batch_json = json.dumps(citations).encode('utf-8')
        fmt_bytes = format.encode('utf-8')
        
        result_ptr = self._lib.citum_render_citations_json(self._ptr, batch_json, fmt_bytes)
        if not result_ptr:
            err = self.get_last_error()
            raise CitumError(f"Batch render failed: {err}")
        
        result_json = self._to_python_string(result_ptr)
        return json.loads(result_json)
