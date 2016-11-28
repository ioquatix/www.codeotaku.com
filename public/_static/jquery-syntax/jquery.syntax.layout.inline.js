// This file is part of the "jQuery.Syntax" project, and is distributed under the MIT License.
// Copyright (c) 2011 Samuel G. D. Williams. <http://www.oriontransfer.co.nz>

Syntax.layouts.inline=function(a,c,b){a=jQuery('<code class="syntax highlighted"></code>');a.append(c.children());b=jQuery('<span class="syntax-container">');b.append(a);return b};
