// This file is part of the "jQuery.Syntax" project, and is distributed under the MIT License.
// Copyright (c) 2011 Samuel G. D. Williams. <http://www.oriontransfer.co.nz>

Syntax.layouts.plain=function(b,c,a){b=jQuery('<div class="toolbar">');a=jQuery('<div class="syntax plain highlighted">');c.removeClass("syntax");a.append(c);return jQuery('<div class="syntax-container">').append(b).append(a)};
