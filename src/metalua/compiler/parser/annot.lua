local gg    = require 'metalua.grammar.generator'
local misc  = require 'metalua.compiler.parser.misc'
local mlp   = require 'metalua.compiler.parser.common'
local lexer = require 'metalua.compiler.parser.lexer'
local M     = { }

lexer.lexer :add '->'

function M.type_id(lx)
    local w = lx :next()
    if w.tag=='Keyword' then w.tag='TId'
    elseif w.tag=='Id' then w.tag='TId'
    else error 'type_id expected' end
    return w
end

local function _annot(...) return M.annot(...) end

local field_types = { var='TVar'; const='TConst';
                      currently='TCurrently'; field='TField' }

function M.field_annot(lx)
    local w = M.type_id(lx)[1]
    local tag = field_types[w]
    if not tag then
        error ('Invalid field type '..w)
    elseif tag=='TField' then
        return {tag='TField'}
    else
        local a = M.annot(lx)
        return {tag=tag; a}
    end
end

M.annot = gg.expr{
    primary = gg.multisequence{ name = 'annotation',
        { M.type_id, builder=function(x) return x[1] end },
        { "(",
          gg.list{
              primary=_annot,
              separators={ ",", ";" },
              terminators=")"
          },
          ")",
          builder=function(x) return x[1] end },
        { "[",
          M.field_annot,
          gg.onkeyword{ ",", ";",
                        gg.list{
                            primary = gg.sequence{
                                expr, ":", field_annot,
                            },
                            separators = { ",", ";" },
                            terminators = "]" } },
          "]",
          builder = function(x)
                        local other, _, fields = unpack(x)
                        fields = fields or { }
                        return { tag='TTable', other, fields }
                    end
      } -- "[ ... ]"
    }, -- primary
    infix = {
        {"->", prec=50, builder=function(a, _, b) return {tag='TFunction', a, b} end } } }

M.stat_annot = gg.sequence{
    gg.list{ primary=M.type_id, separators='.' },
    '=',
    M.annot,
    builder = 'Annot' }

M.annot_id = gg.sequence{
    misc.id,
    gg.onkeyword{ "#", M.field_annot },
    builder = function(x)
                  local id, annot = unpack(x)
                  if annot then return { tag='Annot', id, annot }
                  else return id end
              end }

function M.split(lst)
    local x, a, some = { }, { }, false
    for i, p in ipairs(lst) do
        if p.tag=='Annot' then
            some, x[i], a[i] = true, unpack(p)
        else x[i] = p end
    end
    if some then return x, a else return lst end
end

if false then
mlp.expr.suffix :add{
    "#", M.field_annot, builder = function (e, a)
         printf("Annoting %s with %s", table.tostring(e), table.tostring(a))
         e.annot=a; return e end }
end
return M