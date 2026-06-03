{#
  Par défaut DBT préfixe le schéma cible (ex. PUBLIC_STAGING).
  On surcharge ce comportement pour viser exactement le schéma demandé
  via +schema (STAGING, FINAL) — plus lisible pour ce projet.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
