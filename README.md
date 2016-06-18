# Proxy-Factory
This project is written in Apple Swift Language, provide an interface to switch proxy service goagent and goproxy, and some useful functions for macOS user. 

macOS user can:
1.Switch between goagent and goproxy
2.Toggle system proxy settings without require password(only once) by use SMJobless + XPC
3.Fix port confict automatically
4.Import RootCA to system
5.Update goproxy from github
6.User friendly interface to change general settings such as AppIDs, Password, Proxy Port, IP List, etc. 

*Both goproxy and goagent are developed by phuslu, https://github.com/phuslu/goproxy.

This is also a sample application for SMJobless and XPC written in Swift language. When I started this project, I could not find any SMJobless and XPC samples written in Swift on the Internet. The Apple samples are written in Objective C. In this project, the SMJobless part and helper tool are all implemented in Swift. I may upload a simplified sample with configuration explanation step by step later.
