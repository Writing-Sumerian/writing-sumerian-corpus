# Writing Sumerian Corpus

PostgreSQL extensions to manage, manipulate and analyze a cuneiform text corpus.

## Components

The extensions are organized in four groups:
- **Data** extentions create data structures for primary data, with minimal functionality and dependencies.
- **Module** extensions implement core functionality and are kept as general as possible. They do not expect corpus data structures (as implemented by the `cuneiform_corpus` extension) to be in place and may be useful to manipulate cuneiform data in other contexts.
- **Corpus** extensions add functionality to corpus data structures and require the `cuneiform_corpus` extension. 
- **Test** extensions implement tests for other extensions.

### Data

| Extension | Description | Dependencies |
| --- | --- | --- |
| cuneiform_context | Context information for cuneiform texts |
| cuneiform_signlist | Cuneiform signlist | [py2plpy](https://github.com/marcendesfelder/py2plpy) (build), jsonb_plpython3u |
| cuneiform_corpus | Core data structures for a cuneiform corpus | cuneiform_create_corpus, cuneiform_context |
| cuneiform_log_tables | Log tables for a cuneiform corpus | cuneiform_corpus |
| cuneiform_pn_tables | Tables for cuneiform proper noun data | cuneiform_sign_properties, cuneiform_signlist |

### Modules
| Extension | Description | Dependencies |
| --- | --- | --- |
| cuneiform_actions | Atomic actions to manipulate cuneiform transliterations | |
| cuneiform_citation | Support functions for citing cuneiform passages | [roman](https://github.com/zopefoundation/roman) (Python package), cuneiform_create_corpus |
| cuneiform_create_corpus | Define and create core data structures for a cuneiform corpus | cuneiform_signlist |
| cuneiform_editor | Edit cuneiform transliterations | cuneiform_actions, cuneiform_signlist |
| cuneiform_encoder | Support for encoding cuneiform values and sign variants | cuneiform_sign_properties, cuneiform_signlist |
| cuneiform_log | Support for viewing and undoing changes in cuneiform transliterations | cuneiform_actions |
| cuneiform_parser | Parse human-readable cuneiform code | [writingsumerianparser](https://github.com/Writing-Sumerian/writing-sumerian-parser) (Python package), cuneiform_sign_properties, cuneiform_signlist, cuneiform_create_corpus, cuneiform_encoder |
| cuneiform_pns | Support for searching and manipulating cuneiform proper nouns | cuneiform_sign_properties, cuneiform_signlist, cuneiform_pn_tables, cuneiform_parser, cuneiform_serialize, cuneiform_search |
| cuneiform_print_core | Support functions to build converters to compose cuneiform passages into human-readable text | cuneiform_sign_properties, cuneiform_signlist |
| cuneiform_print_html | Convert cuneiform passages into human-readable text with HTML markup | [py2plpy](https://github.com/marcendesfelder/py2plpy) (build), cuneiform_sign_properties, cuneiform_signlist, cuneiform_print_core |
| cuneiform_replace | Replace cuneiform passages while preserving specific information | [py2plpy](https://github.com/marcendesfelder/py2plpy) (build), [writingsumerianparser](https://github.com/Writing-Sumerian/writing-sumerian-parser) (Python package), cuneiform_create_corpus, cuneiform_encoder, cuneiform_parser, cuneiform_signlist, cuneiform_sign_properties |
| cuneiform_search | Search cuneiform passages | [py2plpy](https://github.com/marcendesfelder/py2plpy) (build), [lark](https://github.com/lark-parser/lark) (Python package), cuneiform_signlist, cuneiform_encoder |
| cuneiform_serialize | Serialize cuneiform passages into human-readable code' | cuneiform_sign_properties, cuneiform_signlist, cuneiform_print_core |
| cuneiform_sign_properties | Basic data types for cuneiform signs | |

### Corpus
| Extension | Description | Dependencies |
| --- | --- | --- |
| cuneiform_cite_corpus | Support for citing passages in a cuneiform corpus | cuneiform_context, cuneiform_corpus, cuneiform_citation |
| cuneiform_corpus_pns | Support for handling proper nouns in a cuneiform corpus | cuneiform_actions, cuneiform_corpus, cuneiform_pn_tables, cuneiform_replace, cuneiform_signlist, cuneiform_sign_properties, cuneiform_log_tables |
| cuneiform_corpus_statistics | Collect statistics in a cuneiform corpus | cuneiform_corpus |
| cuneiform_edit_corpus | Edit transliterations in a cuneiform corpus | cuneiform_sign_properties, cuneiform_create_corpus, cuneiform_corpus, cuneiform_encoder, cuneiform_parser, cuneiform_editor, cuneiform_log, cuneiform_log_tables |
| cuneiform_encode_corpus | Support for encoding and decoding values and sign variants in a cuneiform corpus | cuneiform_sign_properties, cuneiform_signlist, cuneiform_corpus, cuneiform_encoder |
| cuneiform_log_corpus | Support for viewing and undoing changes in a cuneiform corpus | cuneiform_create_corpus, cuneiform_serialize, cuneiform_actions, cuneiform_corpus, cuneiform_log, cuneiform_log_tables |
| cuneiform_print_corpus | Support for converting passages of a cuneiform corpus into human readable text with HTML markup | cuneiform_corpus, cuneiform_print_html |
| cuneiform_replace_corpus | Search and replace passages in a cuneiform corpus | cuneiform_sign_properties, cuneiform_corpus, cuneiform_replace, cuneiform_search, cuneiform_search_corpus, cuneiform_edit_corpus |
| cuneiform_search_corpus | Search passages in a cuneiform corpus | cuneiform_corpus, cuneiform_sign_properties, cuneiform_signlist, cuneiform_serialize, cuneiform_serialize_corpus, cuneiform_search |
| cuneiform_serialize_corpus | Support for serializing passages of a cuneiform corpus into human readable code | cuneiform_corpus, cuneiform_serialize |

### Test
| Extension | Description | Dependencies |
| --- | --- | --- |
| cuneiform_test | Test basic cuneiform corpus functionality | [pgtap](https://github.com/theory/pgtap/), cuneiform_actions, cuneiform_log, cuneiform_encoder, cuneiform_parser, cuneiform_context, cuneiform_corpus, cuneiform_serialize_corpus, cuneiform_log_corpus, cuneiform_edit_corpus, cuneiform_replace_corpus |
| cuneiform_test_pns | Test cuneiform proper nouns manipulation | [pgtap](https://github.com/theory/pgtap/), cuneiform_encoder, cuneiform_parser, cuneiform_context, cuneiform_corpus, cuneiform_serialize_corpus, cuneiform_pn_tables, cuneiform_pns, cuneiform_corpus_pns |