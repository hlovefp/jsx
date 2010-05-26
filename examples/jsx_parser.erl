%% The MIT License

%% Copyright (c) 2010 <alisdairsullivan@yahoo.ca>

%% Permission is hereby granted, free of charge, to any person obtaining a copy
%% of this software and associated documentation files (the "Software"), to deal
%% in the Software without restriction, including without limitation the rights
%% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
%% copies of the Software, and to permit persons to whom the Software is
%% furnished to do so, subject to the following conditions:

%% The above copyright notice and this permission notice shall be included in
%% all copies or substantial portions of the Software.

%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
%% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
%% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
%% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
%% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
%% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
%% THE SOFTWARE.

-author("alisdairsullivan@yahoo.ca").


-module(jsx_parser).

-export([decode/2, event/2]).
-export([literal/1, string/1, number/1]).


%% this is a strict parser, no comments, no naked values and only one key per object. it
%%   also is not streaming, though it could be modified to parse partial objects/lists.

decode(JSON, Opts) ->
    P = jsx:decoder({{jsx_parser, event}, []}, Opts),
    {Result, Rest} = P(JSON),
    case jsx:tail_clean(Rest) of
        true -> Result
        ; _ -> exit(badarg)
    end.
 
%% erlang representation is dicts for objects and lists for arrays. these are pushed
%%   onto a stack, the top of which is our current level, deeper levels represent parent
%%   and grandparent levels in the json structure. keys are also stored on top of the array
%%   during parsing of their associated values.
    
event(start_object, Stack) ->
    [dict:new()] ++ Stack;
event(start_array, Stack) ->
    [[]] ++ Stack;
    

event(end_object, [Object, {key, Key}, Parent|Stack]) when is_tuple(Parent) ->
    [insert(Key, Object, Parent)] ++ Stack;
event(end_array, [Array, {key, Key}, Parent|Stack]) when is_tuple(Parent) ->
    [insert(Key, Array, Parent)] ++ Stack;    
event(end_object, [Object, Parent|Stack]) when is_list(Parent) ->
    [[Object] ++ Parent] ++ Stack;
event(end_array, [Array, Parent|Stack]) when is_list(Parent) ->
    [[Array] ++ Parent] ++ Stack;

%% special cases for closing the root objects
event(end_object, [Object]) ->
    [Object];
event(end_array, [Array]) ->
    [Array];    
    
event({key, Key}, [Object|Stack]) ->
    [{key, Key}] ++ [Object] ++ Stack;

%% this is kind of a dirty hack, but erlang will interpret atoms when applied to (Args)
%%   as a function. so naming out formatting functions string, number and literal will
%%   allow the following shortcut

event({Type, Value}, [{key, Key}, Object|Stack]) ->
    [insert(Key, ?MODULE:Type(Value), Object)] ++ Stack;
event({Type, Value}, [Array|Stack]) when is_list(Array) ->
    [[?MODULE:Type(Value)] ++ Array] ++ Stack;
    
event(eof, [Stack]) ->
    Stack.
    

%% we're restricting keys to one occurence per object, as the spec implies.    
    
insert(Key, Val, Dict) ->
    case dict:is_key(Key, Dict) of
        false -> dict:store(Key, Val, Dict)
        ; true -> exit(badarg)
    end.
    

%% strings, numbers and literals we just return with no post-processing, this is where we
%%   would deal with them though.
   
string(String) ->
    String.
number(Number) ->
    Number.
literal(Literal) ->
    Literal.
    

