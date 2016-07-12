public final class ResourceBuilder : RouterBuilder {
    let viewsPath: String
    let file: FileProtocol.Type

    init(path: String, viewsPath: String, file: FileProtocol.Type) {
        self.viewsPath = viewsPath
        self.file = file
        super.init(path: path)
    }
}

extension ResourceBuilder {
    public func get<
        ActionOutput: StructuredDataFallibleRepresentable
        >(
        _ path: String,
        middleware: Middleware...,
        action: (Void) throws -> ActionOutput,
        view: String
        ) {
        let mustacheSerializer = MustacheSerializer(templatePath: "Views/\(viewsPath)/\(view)", file: file)
        let templateMiddleware = TemplateEngineMiddleware(serializer: mustacheSerializer)
        let responder = BasicResponder { request in
            let actionOutput = try action()
            return try Response(content: actionOutput)
        }
        addRoute(
            method: .get,
            path: path,
            middleware: [templateMiddleware] + middleware,
            responder: responder
        )
    }

    public func get<
        ActionOutput: StructuredDataFallibleRepresentable,
        RenderOutput: StructuredDataFallibleRepresentable
        >(
        _ path: String,
        middleware: Middleware...,
        action: (Void) throws -> ActionOutput,
        render: (ActionOutput) throws -> RenderOutput,
        view: String
        ) {
        let mustacheSerializer = MustacheSerializer(templatePath: "Views/\(viewsPath)/\(view)", file: file)
        let templateMiddleware = TemplateEngineMiddleware(serializer: mustacheSerializer)
        let responder = BasicResponder { request in
            let actionOutput = try action()
            let renderOutput = try render(actionOutput)
            return try Response(content: renderOutput)
        }
        addRoute(
            method: .get,
            path: path,
            middleware: [templateMiddleware] + middleware,
            responder: responder
        )
    }









    public func post<
        A: PathParameterInitializable,
        I: StructuredDataInitializable,
        O: StructuredDataFallibleRepresentable
        >(
        _ path: String,
        middleware: Middleware...,
        action: (A, I) throws -> O) {
        addRoute(method: .post, path: path, middleware: middleware, action: action)
    }

    public func addRoute<
        A: PathParameterInitializable,
        I: StructuredDataInitializable,
        O: StructuredDataFallibleRepresentable
        >(
        method: Method,
        path: String,
        middleware: [Middleware],
        action: (A, I) throws -> O) {
        let keys = parseParameterKeys(path: path, count: 1)
        let contentMapper = ContentMapperMiddleware(mappingTo: I.self)
        let responder = BasicResponder { request in
            let parameters = try self.parseParameters(
                keys: keys,
                pathParameters: request.pathParameters,
                count: 1
            )

            let a = try A(pathParameter: parameters[0])

            guard let input = request.storage[I.key] as? I else {
                throw ClientError.badRequest
            }

            let output = try action(a, input)

            return try Response(content: output)
        }

        addRoute(method: method, path: path, middleware: [contentMapper] + middleware, responder: responder)
    }
}

extension ResourceBuilder {
    public func list<
        ActionOutput: StructuredDataFallibleRepresentable,
        RenderOutput: StructuredDataFallibleRepresentable
        >(
        middleware: Middleware...,
        action: (Void) throws -> [ActionOutput],
        render: ([ActionOutput]) throws -> RenderOutput
        ) {
        let mustacheSerializer = MustacheSerializer(templatePath: "Views/\(viewsPath)/list.html", file: file)
        let templateMiddleware = TemplateEngineMiddleware(serializer: mustacheSerializer)
        let responder = BasicResponder { request in
            let actionOutput = try action()
            do {
                let renderOutput = try render(actionOutput)
                return try Response(content: renderOutput)
            } catch PresenterError.bypass {
                return try Response(content: actionOutput)
            }
        }
        addRoute(
            method: .get,
            path: "",
            middleware: [templateMiddleware] + middleware,
            responder: responder
        )
    }

    public func create<
        CreateInput: StructuredDataInitializable,
        CreateOutput: StructuredDataFallibleRepresentable
        >(
        middleware: Middleware...,
        action: (CreateInput) throws -> CreateOutput) {
        let contentMapper = ContentMapperMiddleware(mappingTo: CreateInput.self)
        let responder = BasicResponder { request in
            guard let input = request.storage[CreateInput.key] as? CreateInput else {
                throw ClientError.badRequest
            }
            let output = try action(input)
            return try Response(content: output)
        }
        addRoute(method: .post, path: "", middleware: [contentMapper] + middleware, responder: responder)
    }

    public func detail<
        ID: PathParameterInitializable,
        DetailOutput: StructuredDataFallibleRepresentable
        >(
        middleware: Middleware...,
        action: (ID) throws -> DetailOutput) {
        let responder = BasicResponder { request in
            let id = try ID(pathParameter: request.pathParameters["id"]!)
            let output = try action(id)
            return try Response(content: output)
        }
        addRoute(method: .get, path: "/:id", middleware: middleware, responder: responder)
    }

    public func update<
        ID: PathParameterInitializable,
        UpdateInput: StructuredDataInitializable,
        UpdateOutput: StructuredDataFallibleRepresentable
        >(
        middleware: Middleware...,
        action: (ID, UpdateInput) throws -> UpdateOutput) {
        let contentMapper = ContentMapperMiddleware(mappingTo: UpdateInput.self)
        let responder = BasicResponder { request in
            guard let input = request.storage[UpdateInput.key] as? UpdateInput else {
                throw ClientError.badRequest
            }
            let id = try ID(pathParameter: request.pathParameters["id"]!)
            let output = try action(id, input)
            return try Response(content: output)
        }
        addRoute(method: .patch, path: "/:id", middleware: [contentMapper] + middleware, responder: responder)
    }

    public func destroy<
        ID: PathParameterInitializable,
        DestroyOutput: StructuredDataFallibleRepresentable
        >(
        middleware: Middleware...,
        action: (ID) throws -> DestroyOutput?) {
        let responder = BasicResponder { request in
            let id = try ID(pathParameter: request.pathParameters["id"]!)
            let output = try action(id)
            return try Response(content: output)
        }
        addRoute(method: .delete, path: "/:id", middleware: middleware, responder: responder)
    }
}

extension ResourceBuilder {
    public func detail<
        DetailOutput: StructuredDataFallibleRepresentable
        >(
        _ action: (Void) throws -> DetailOutput) {
        detail(action: action)
    }

    public func detail<
        DetailOutput: StructuredDataFallibleRepresentable
        >(
        middleware: Middleware...,
        action: (Void) throws -> DetailOutput) {
        let responder = BasicResponder { request in
            let output = try action()
            return try Response(content: output)
        }
        addRoute(method: .get, path: "", middleware: middleware, responder: responder)
    }

    public func update<
        UpdateInput: StructuredDataInitializable,
        UpdateOutput: StructuredDataFallibleRepresentable
        >(
        _ action: (UpdateInput) throws -> UpdateOutput) {
        update(action: action)
    }

    public func update<
        UpdateInput: StructuredDataInitializable,
        UpdateOutput: StructuredDataFallibleRepresentable
        >(
        middleware: Middleware...,
        action: (UpdateInput) throws -> UpdateOutput) {
        let contentMapper = ContentMapperMiddleware(mappingTo: UpdateInput.self)
        let responder = BasicResponder { request in
            guard let input = request.storage[UpdateInput.key] as? UpdateInput else {
                throw ClientError.badRequest
            }
            let output = try action(input)
            return try Response(content: output)
        }
        addRoute(method: .patch, path: "", middleware: [contentMapper] + middleware, responder: responder)
    }

    public func destroy<
        DestroyOutput: StructuredDataFallibleRepresentable
        >(
        _ action: (Void) throws -> DestroyOutput?) {
        destroy(action: action)
    }

    public func destroy<
        DestroyOutput: StructuredDataFallibleRepresentable
        >(
        middleware: Middleware...,
        action: (Void) throws -> DestroyOutput?) {
        let responder = BasicResponder { request in
            guard let output = try action() else {
                return Response(status: .noContent)
            }
            return try Response(content: output)
        }
        addRoute(method: .delete, path: "", middleware: middleware, responder: responder)
    }
}


//extension ResourceBuilder {
//    public func get(
//        middleware: Middleware...,
//        respond: Respond) {
//        addRoute(method: .get, path: "", middleware: middleware, respond: respond)
//    }
//
//    public func get<
//        A: PathParameterInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        middleware: Middleware...,
//        respond: (Request, A) throws -> Response) {
//        addRoute(method: .get, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func get<
//        A: PathParameterInitializable,
//        B: PathParameterInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        _: B.Type = B.self,
//        middleware: Middleware...,
//        respond: (Request, (A, B)) throws -> Response) {
//        addRoute(method: .get, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func get<
//        A: PathParameterInitializable,
//        B: PathParameterInitializable,
//        C: PathParameterInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        _: B.Type = B.self,
//        _: C.Type = C.self,
//        middleware: Middleware...,
//        respond: (Request, (A, B, C)) throws -> Response) {
//        addRoute(method: .get, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func get<
//        A: PathParameterInitializable,
//        B: PathParameterInitializable,
//        C: PathParameterInitializable,
//        D: PathParameterInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        _: B.Type = B.self,
//        _: C.Type = C.self,
//        _: D.Type = D.self,
//        middleware: Middleware...,
//        respond: (Request, (A, B, C, D)) throws -> Response) {
//        addRoute(method: .get, path: path, middleware: middleware, respond: respond)
//    }
//}
//
//extension ResourceBuilder {
//    public func head(
//        middleware: Middleware...,
//        respond: Respond) {
//        addRoute(method: .head, path: "", middleware: middleware, respond: respond)
//    }
//
//    public func head<
//        A: PathParameterInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        middleware: Middleware...,
//        respond: (Request, A) throws -> Response) {
//        addRoute(method: .head, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func head<
//        A: PathParameterInitializable,
//        B: PathParameterInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        _: B.Type = B.self,
//        middleware: Middleware...,
//        respond: (Request, (A, B)) throws -> Response) {
//        addRoute(method: .head, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func head<
//        A: PathParameterInitializable,
//        B: PathParameterInitializable,
//        C: PathParameterInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        _: B.Type = B.self,
//        _: C.Type = C.self,
//        middleware: Middleware...,
//        respond: (Request, (A, B, C)) throws -> Response) {
//        addRoute(method: .head, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func head<
//        A: PathParameterInitializable,
//        B: PathParameterInitializable,
//        C: PathParameterInitializable,
//        D: PathParameterInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        _: B.Type = B.self,
//        _: C.Type = C.self,
//        _: D.Type = D.self,
//        middleware: Middleware...,
//        respond: (Request, (A, B, C, D)) throws -> Response) {
//        addRoute(method: .head, path: path, middleware: middleware, respond: respond)
//    }
//}
//
//extension ResourceBuilder {
//    public func post(
//        middleware: Middleware...,
//        respond: Respond) {
//        addRoute(method: .post, path: "", middleware: middleware, respond: respond)
//    }
//
//    public func post(
//        _ path: String = "",
//        middleware: Middleware...,
//        respond: (Request, StructuredData) throws -> Response) {
//        addRoute(method: .post, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func post<
//        T: StructuredDataInitializable
//        >(
//        _ path: String = "",
//        middleware: Middleware...,
//        content: T.Type = T.self,
//        respond: (Request, T) throws -> Response) {
//        addRoute(method: .post, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func post<
//        A: PathParameterInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        middleware: Middleware...,
//        respond: (Request, A) throws -> Response) {
//        addRoute(method: .post, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func post<
//        A: PathParameterInitializable,
//        B: PathParameterInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        _: B.Type = B.self,
//        middleware: Middleware...,
//        respond: (Request, (A, B)) throws -> Response) {
//        addRoute(method: .post, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func post<
//        A: PathParameterInitializable,
//        B: PathParameterInitializable,
//        C: PathParameterInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        _: B.Type = B.self,
//        _: C.Type = C.self,
//        middleware: Middleware...,
//        respond: (Request, (A, B, C)) throws -> Response) {
//        addRoute(method: .post, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func post<
//        A: PathParameterInitializable,
//        B: PathParameterInitializable,
//        C: PathParameterInitializable,
//        D: PathParameterInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        _: B.Type = B.self,
//        _: C.Type = C.self,
//        _: D.Type = D.self,
//        middleware: Middleware...,
//        respond: (Request, (A, B, C, D)) throws -> Response) {
//        addRoute(method: .post, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func post<
//        A: PathParameterInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        middleware: Middleware...,
//        respond: (Request, A, StructuredData) throws -> Response) {
//        addRoute(method: .post, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func post<
//        A: PathParameterInitializable,
//        B: PathParameterInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        _: B.Type = B.self,
//        middleware: Middleware...,
//        respond: (Request, (A, B), StructuredData) throws -> Response) {
//        addRoute(method: .post, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func post<
//        A: PathParameterInitializable,
//        B: PathParameterInitializable,
//        C: PathParameterInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        _: B.Type = B.self,
//        _: C.Type = C.self,
//        middleware: Middleware...,
//        respond: (Request, (A, B, C), StructuredData) throws -> Response) {
//        addRoute(method: .post, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func post<
//        A: PathParameterInitializable,
//        B: PathParameterInitializable,
//        C: PathParameterInitializable,
//        D: PathParameterInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        _: B.Type = B.self,
//        _: C.Type = C.self,
//        _: D.Type = D.self,
//        middleware: Middleware...,
//        respond: (Request, (A, B, C, D), StructuredData) throws -> Response) {
//        addRoute(method: .post, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func post<
//        A: PathParameterInitializable,
//        T: StructuredDataInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        middleware: Middleware...,
//        content: T.Type = T.self,
//        respond: (Request, A, T) throws -> Response) {
//        addRoute(method: .post, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func post<
//        A: PathParameterInitializable,
//        B: PathParameterInitializable,
//        T: StructuredDataInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        _: B.Type = B.self,
//        middleware: Middleware...,
//        content: T.Type = T.self,
//        respond: (Request, (A, B), T) throws -> Response) {
//        addRoute(method: .post, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func post<
//        A: PathParameterInitializable,
//        B: PathParameterInitializable,
//        C: PathParameterInitializable,
//        T: StructuredDataInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        _: B.Type = B.self,
//        _: C.Type = C.self,
//        middleware: Middleware...,
//        content: T.Type = T.self,
//        respond: (Request, (A, B, C), T) throws -> Response) {
//        addRoute(method: .post, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func post<
//        A: PathParameterInitializable,
//        B: PathParameterInitializable,
//        C: PathParameterInitializable,
//        D: PathParameterInitializable,
//        T: StructuredDataInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        _: B.Type = B.self,
//        _: C.Type = C.self,
//        _: D.Type = D.self,
//        middleware: Middleware...,
//        content: T.Type = T.self,
//        respond: (Request, (A, B, C, D), T) throws -> Response) {
//        addRoute(method: .post, path: path, middleware: middleware, respond: respond)
//    }
//}
//
//extension ResourceBuilder {
//    public func put(
//        middleware: Middleware...,
//        respond: Respond) {
//        addRoute(method: .put, path: "", middleware: middleware, respond: respond)
//    }
//
//    public func put(
//        _ path: String = "",
//        middleware: Middleware...,
//        respond: (Request, StructuredData) throws -> Response) {
//        addRoute(method: .put, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func put<
//        T: StructuredDataInitializable
//        >(
//        _ path: String = "",
//        middleware: Middleware...,
//        content: T.Type = T.self,
//        respond: (Request, T) throws -> Response) {
//        addRoute(method: .put, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func put<
//        A: PathParameterInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        middleware: Middleware...,
//        respond: (Request, A) throws -> Response) {
//        addRoute(method: .put, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func put<
//        A: PathParameterInitializable,
//        B: PathParameterInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        _: B.Type = B.self,
//        middleware: Middleware...,
//        respond: (Request, (A, B)) throws -> Response) {
//        addRoute(method: .put, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func put<
//        A: PathParameterInitializable,
//        B: PathParameterInitializable,
//        C: PathParameterInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        _: B.Type = B.self,
//        _: C.Type = C.self,
//        middleware: Middleware...,
//        respond: (Request, (A, B, C)) throws -> Response) {
//        addRoute(method: .put, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func put<
//        A: PathParameterInitializable,
//        B: PathParameterInitializable,
//        C: PathParameterInitializable,
//        D: PathParameterInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        _: B.Type = B.self,
//        _: C.Type = C.self,
//        _: D.Type = D.self,
//        middleware: Middleware...,
//        respond: (Request, (A, B, C, D)) throws -> Response) {
//        addRoute(method: .put, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func put<
//        A: PathParameterInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        middleware: Middleware...,
//        respond: (Request, A, StructuredData) throws -> Response) {
//        addRoute(method: .put, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func put<
//        A: PathParameterInitializable,
//        B: PathParameterInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        _: B.Type = B.self,
//        middleware: Middleware...,
//        respond: (Request, (A, B), StructuredData) throws -> Response) {
//        addRoute(method: .put, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func put<
//        A: PathParameterInitializable,
//        B: PathParameterInitializable,
//        C: PathParameterInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        _: B.Type = B.self,
//        _: C.Type = C.self,
//        middleware: Middleware...,
//        respond: (Request, (A, B, C), StructuredData) throws -> Response) {
//        addRoute(method: .put, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func put<
//        A: PathParameterInitializable,
//        B: PathParameterInitializable,
//        C: PathParameterInitializable,
//        D: PathParameterInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        _: B.Type = B.self,
//        _: C.Type = C.self,
//        _: D.Type = D.self,
//        middleware: Middleware...,
//        respond: (Request, (A, B, C, D), StructuredData) throws -> Response) {
//        addRoute(method: .put, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func put<
//        A: PathParameterInitializable,
//        T: StructuredDataInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        middleware: Middleware...,
//        content: T.Type = T.self,
//        respond: (Request, A, T) throws -> Response) {
//        addRoute(method: .put, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func put<
//        A: PathParameterInitializable,
//        B: PathParameterInitializable,
//        T: StructuredDataInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        _: B.Type = B.self,
//        middleware: Middleware...,
//        content: T.Type = T.self,
//        respond: (Request, (A, B), T) throws -> Response) {
//        addRoute(method: .put, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func put<
//        A: PathParameterInitializable,
//        B: PathParameterInitializable,
//        C: PathParameterInitializable,
//        T: StructuredDataInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        _: B.Type = B.self,
//        _: C.Type = C.self,
//        middleware: Middleware...,
//        content: T.Type = T.self,
//        respond: (Request, (A, B, C), T) throws -> Response) {
//        addRoute(method: .put, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func put<
//        A: PathParameterInitializable,
//        B: PathParameterInitializable,
//        C: PathParameterInitializable,
//        D: PathParameterInitializable,
//        T: StructuredDataInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        _: B.Type = B.self,
//        _: C.Type = C.self,
//        _: D.Type = D.self,
//        middleware: Middleware...,
//        content: T.Type = T.self,
//        respond: (Request, (A, B, C, D), T) throws -> Response) {
//        addRoute(method: .put, path: path, middleware: middleware, respond: respond)
//    }
//}
//
//extension ResourceBuilder {
//    public func patch(
//        middleware: Middleware...,
//        respond: Respond) {
//        addRoute(method: .patch, path: "", middleware: middleware, respond: respond)
//    }
//
//    public func patch(
//        _ path: String = "",
//        middleware: Middleware...,
//        respond: (Request, StructuredData) throws -> Response) {
//        addRoute(method: .patch, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func patch<
//        T: StructuredDataInitializable
//        >(
//        _ path: String = "",
//        middleware: Middleware...,
//        content: T.Type = T.self,
//        respond: (Request, T) throws -> Response) {
//        addRoute(method: .patch, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func patch<
//        A: PathParameterInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        middleware: Middleware...,
//        respond: (Request, A) throws -> Response) {
//        addRoute(method: .patch, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func patch<
//        A: PathParameterInitializable,
//        B: PathParameterInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        _: B.Type = B.self,
//        middleware: Middleware...,
//        respond: (Request, (A, B)) throws -> Response) {
//        addRoute(method: .patch, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func patch<
//        A: PathParameterInitializable,
//        B: PathParameterInitializable,
//        C: PathParameterInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        _: B.Type = B.self,
//        _: C.Type = C.self,
//        middleware: Middleware...,
//        respond: (Request, (A, B, C)) throws -> Response) {
//        addRoute(method: .patch, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func patch<
//        A: PathParameterInitializable,
//        B: PathParameterInitializable,
//        C: PathParameterInitializable,
//        D: PathParameterInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        _: B.Type = B.self,
//        _: C.Type = C.self,
//        _: D.Type = D.self,
//        middleware: Middleware...,
//        respond: (Request, (A, B, C, D)) throws -> Response) {
//        addRoute(method: .patch, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func patch<
//        A: PathParameterInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        middleware: Middleware...,
//        respond: (Request, A, StructuredData) throws -> Response) {
//        addRoute(method: .patch, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func patch<
//        A: PathParameterInitializable,
//        B: PathParameterInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        _: B.Type = B.self,
//        middleware: Middleware...,
//        respond: (Request, (A, B), StructuredData) throws -> Response) {
//        addRoute(method: .patch, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func patch<
//        A: PathParameterInitializable,
//        B: PathParameterInitializable,
//        C: PathParameterInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        _: B.Type = B.self,
//        _: C.Type = C.self,
//        middleware: Middleware...,
//        respond: (Request, (A, B, C), StructuredData) throws -> Response) {
//        addRoute(method: .patch, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func patch<
//        A: PathParameterInitializable,
//        B: PathParameterInitializable,
//        C: PathParameterInitializable,
//        D: PathParameterInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        _: B.Type = B.self,
//        _: C.Type = C.self,
//        _: D.Type = D.self,
//        middleware: Middleware...,
//        respond: (Request, (A, B, C, D), StructuredData) throws -> Response) {
//        addRoute(method: .patch, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func patch<
//        A: PathParameterInitializable,
//        T: StructuredDataInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        middleware: Middleware...,
//        content: T.Type = T.self,
//        respond: (Request, A, T) throws -> Response) {
//        addRoute(method: .patch, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func patch<
//        A: PathParameterInitializable,
//        B: PathParameterInitializable,
//        T: StructuredDataInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        _: B.Type = B.self,
//        middleware: Middleware...,
//        content: T.Type = T.self,
//        respond: (Request, (A, B), T) throws -> Response) {
//        addRoute(method: .patch, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func patch<
//        A: PathParameterInitializable,
//        B: PathParameterInitializable,
//        C: PathParameterInitializable,
//        T: StructuredDataInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        _: B.Type = B.self,
//        _: C.Type = C.self,
//        middleware: Middleware...,
//        content: T.Type = T.self,
//        respond: (Request, (A, B, C), T) throws -> Response) {
//        addRoute(method: .patch, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func patch<
//        A: PathParameterInitializable,
//        B: PathParameterInitializable,
//        C: PathParameterInitializable,
//        D: PathParameterInitializable,
//        T: StructuredDataInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        _: B.Type = B.self,
//        _: C.Type = C.self,
//        _: D.Type = D.self,
//        middleware: Middleware...,
//        content: T.Type = T.self,
//        respond: (Request, (A, B, C, D), T) throws -> Response) {
//        addRoute(method: .patch, path: path, middleware: middleware, respond: respond)
//    }
//}
//
//extension ResourceBuilder {
//    public func delete(
//        middleware: Middleware...,
//        respond: Respond) {
//        addRoute(method: .delete, path: "", middleware: middleware, respond: respond)
//    }
//
//    public func delete(
//        _ path: String = "",
//        middleware: Middleware...,
//        respond: (Request, StructuredData) throws -> Response) {
//        addRoute(method: .delete, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func delete<
//        T: StructuredDataInitializable
//        >(
//        _ path: String = "",
//        middleware: Middleware...,
//        content: T.Type = T.self,
//        respond: (Request, T) throws -> Response) {
//        addRoute(method: .delete, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func delete<
//        A: PathParameterInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        middleware: Middleware...,
//        respond: (Request, A) throws -> Response) {
//        addRoute(method: .delete, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func delete<
//        A: PathParameterInitializable,
//        B: PathParameterInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        _: B.Type = B.self,
//        middleware: Middleware...,
//        respond: (Request, (A, B)) throws -> Response) {
//        addRoute(method: .delete, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func delete<
//        A: PathParameterInitializable,
//        B: PathParameterInitializable,
//        C: PathParameterInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        _: B.Type = B.self,
//        _: C.Type = C.self,
//        middleware: Middleware...,
//        respond: (Request, (A, B, C)) throws -> Response) {
//        addRoute(method: .delete, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func delete<
//        A: PathParameterInitializable,
//        B: PathParameterInitializable,
//        C: PathParameterInitializable,
//        D: PathParameterInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        _: B.Type = B.self,
//        _: C.Type = C.self,
//        _: D.Type = D.self,
//        middleware: Middleware...,
//        respond: (Request, (A, B, C, D)) throws -> Response) {
//        addRoute(method: .delete, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func delete<
//        A: PathParameterInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        middleware: Middleware...,
//        respond: (Request, A, StructuredData) throws -> Response) {
//        addRoute(method: .delete, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func delete<
//        A: PathParameterInitializable,
//        B: PathParameterInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        _: B.Type = B.self,
//        middleware: Middleware...,
//        respond: (Request, (A, B), StructuredData) throws -> Response) {
//        addRoute(method: .delete, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func delete<
//        A: PathParameterInitializable,
//        B: PathParameterInitializable,
//        C: PathParameterInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        _: B.Type = B.self,
//        _: C.Type = C.self,
//        middleware: Middleware...,
//        respond: (Request, (A, B, C), StructuredData) throws -> Response) {
//        addRoute(method: .delete, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func delete<
//        A: PathParameterInitializable,
//        B: PathParameterInitializable,
//        C: PathParameterInitializable,
//        D: PathParameterInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        _: B.Type = B.self,
//        _: C.Type = C.self,
//        _: D.Type = D.self,
//        middleware: Middleware...,
//        respond: (Request, (A, B, C, D), StructuredData) throws -> Response) {
//        addRoute(method: .delete, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func delete<
//        A: PathParameterInitializable,
//        T: StructuredDataInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        middleware: Middleware...,
//        content: T.Type = T.self,
//        respond: (Request, A, T) throws -> Response) {
//        addRoute(method: .delete, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func delete<
//        A: PathParameterInitializable,
//        B: PathParameterInitializable,
//        T: StructuredDataInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        _: B.Type = B.self,
//        middleware: Middleware...,
//        content: T.Type = T.self,
//        respond: (Request, (A, B), T) throws -> Response) {
//        addRoute(method: .delete, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func delete<
//        A: PathParameterInitializable,
//        B: PathParameterInitializable,
//        C: PathParameterInitializable,
//        T: StructuredDataInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        _: B.Type = B.self,
//        _: C.Type = C.self,
//        middleware: Middleware...,
//        content: T.Type = T.self,
//        respond: (Request, (A, B, C), T) throws -> Response) {
//        addRoute(method: .delete, path: path, middleware: middleware, respond: respond)
//    }
//
//    public func delete<
//        A: PathParameterInitializable,
//        B: PathParameterInitializable,
//        C: PathParameterInitializable,
//        D: PathParameterInitializable,
//        T: StructuredDataInitializable
//        >(
//        _ path: String,
//        _: A.Type = A.self,
//        _: B.Type = B.self,
//        _: C.Type = C.self,
//        _: D.Type = D.self,
//        middleware: Middleware...,
//        content: T.Type = T.self,
//        respond: (Request, (A, B, C, D), T) throws -> Response) {
//        addRoute(method: .delete, path: path, middleware: middleware, respond: respond)
//    }
//}

extension ResourceBuilder {
    public func options(
        _ path: String = "",
        middleware: Middleware...,
        respond: (Void) throws -> Response) {
        addRoute(method: .options, path: path, middleware: middleware, respond: respond)
    }

    public func options(
        middleware: Middleware...,
        respond: Respond) {
        addRoute(method: .options, path: "", middleware: middleware, respond: respond)
    }

    public func options(
        _ path: String = "",
        middleware: Middleware...,
        respond: (Request, StructuredData) throws -> Response) {
        addRoute(method: .options, path: path, middleware: middleware, respond: respond)
    }

    public func options<
        T: StructuredDataInitializable
        >(
        _ path: String = "",
        middleware: Middleware...,
        content: T.Type = T.self,
        respond: (Request, T) throws -> Response) {
        addRoute(method: .options, path: path, middleware: middleware, respond: respond)
    }

    public func options<
        A: PathParameterInitializable
        >(
        _ path: String,
        _: A.Type = A.self,
        middleware: Middleware...,
        respond: (Request, A) throws -> Response) {
        addRoute(method: .options, path: path, middleware: middleware, respond: respond)
    }

    public func options<
        A: PathParameterInitializable,
        B: PathParameterInitializable
        >(
        _ path: String,
        _: A.Type = A.self,
        _: B.Type = B.self,
        middleware: Middleware...,
        respond: (Request, A, B) throws -> Response) {
        addRoute(method: .options, path: path, middleware: middleware, respond: respond)
    }

    public func options<
        A: PathParameterInitializable,
        B: PathParameterInitializable,
        C: PathParameterInitializable
        >(
        _ path: String,
        _: A.Type = A.self,
        _: B.Type = B.self,
        _: C.Type = C.self,
        middleware: Middleware...,
        respond: (Request, A, B, C) throws -> Response) {
        addRoute(method: .options, path: path, middleware: middleware, respond: respond)
    }

    public func options<
        A: PathParameterInitializable,
        B: PathParameterInitializable,
        C: PathParameterInitializable,
        D: PathParameterInitializable
        >(
        _ path: String,
        _: A.Type = A.self,
        _: B.Type = B.self,
        _: C.Type = C.self,
        _: D.Type = D.self,
        middleware: Middleware...,
        respond: (Request, A, B, C, D) throws -> Response) {
        addRoute(method: .options, path: path, middleware: middleware, respond: respond)
    }

    public func options<
        A: PathParameterInitializable,
        T: StructuredDataInitializable
        >(
        _ path: String,
        _: A.Type = A.self,
        middleware: Middleware...,
        content: T.Type = T.self,
        respond: (Request, A, T) throws -> Response) {
        addRoute(method: .options, path: path, middleware: middleware, respond: respond)
    }

    public func options<
        A: PathParameterInitializable,
        B: PathParameterInitializable,
        T: StructuredDataInitializable
        >(
        _ path: String,
        _: A.Type = A.self,
        _: B.Type = B.self,
        middleware: Middleware...,
        content: T.Type = T.self,
        respond: (Request, A, B, T) throws -> Response) {
        addRoute(method: .options, path: path, middleware: middleware, respond: respond)
    }

    public func options<
        A: PathParameterInitializable,
        B: PathParameterInitializable,
        C: PathParameterInitializable,
        T: StructuredDataInitializable
        >(
        _ path: String,
        _: A.Type = A.self,
        _: B.Type = B.self,
        _: C.Type = C.self,
        middleware: Middleware...,
        content: T.Type = T.self,
        respond: (Request, A, B, C, T) throws -> Response) {
        addRoute(method: .options, path: path, middleware: middleware, respond: respond)
    }

    public func options<
        A: PathParameterInitializable,
        B: PathParameterInitializable,
        C: PathParameterInitializable,
        D: PathParameterInitializable,
        T: StructuredDataInitializable
        >(
        _ path: String,
        _: A.Type = A.self,
        _: B.Type = B.self,
        _: C.Type = C.self,
        _: D.Type = D.self,
        middleware: Middleware...,
        content: T.Type = T.self,
        respond: (Request, A, B, C, D, T) throws -> Response) {
        addRoute(method: .options, path: path, middleware: middleware, respond: respond)
    }
}

extension ResourceBuilder {
    public func addRoute(
        method: Method,
        path: String,
        middleware: [Middleware],
        respond: (Void) throws -> Response) {
        let responder = BasicResponder { _ in
            return try respond()
        }
        addRoute(method: method, path: path, middleware: middleware, responder: responder)
    }

    // Todo: make RouterBuilder have "" as the default path
    public func addRoute(
        method: Method,
        path: String,
        middleware: [Middleware],
        respond: Respond) {
        addRoute(method: method, path: path, middleware: middleware, responder: BasicResponder(respond))
    }

    public func addRoute(
        method: Method,
        path: String,
        middleware: [Middleware],
        respond: (request: Request, content: StructuredData) throws -> Response) {
        let responder = BasicResponder { request in
            guard let content = request.content else {
                throw ClientError.badRequest
            }
            return try respond(request: request, content: content)
        }
        addRoute(method: method, path: path, middleware: middleware, responder: responder)
    }

    public func addRoute<
        T: StructuredDataInitializable
        >(
        method: Method,
        path: String,
        middleware: [Middleware],
        content: T.Type = T.self,
        respond: (request: Request, content: T) throws -> Response) {
        let contentMapper = ContentMapperMiddleware(mappingTo: content)
        let responder = BasicResponder { request in
            guard let content = request.storage[T.key] as? T else {
                throw ClientError.badRequest
            }
            return try respond(request: request, content: content)
        }
        addRoute(method: method, path: path, middleware: [contentMapper] + middleware, responder: responder)
    }

    public func addRoute<
        A: PathParameterInitializable
        >(
        method: Method,
        path: String,
        _: A.Type = A.self,
        middleware: [Middleware],
        respond: (Request, A) throws -> Response) {
        let keys = parseParameterKeys(path: path, count: 1)
        let responder = BasicResponder { request in
            let parameters = try self.parseParameters(
                keys: keys,
                pathParameters: request.pathParameters,
                count: 1
            )

            let a = try A(pathParameter: parameters[0])

            return try respond(request, a)
        }

        addRoute(method: method, path: path, middleware: middleware, responder: responder)
    }

    public func addRoute<
        A: PathParameterInitializable,
        B: PathParameterInitializable
        >(
        method: Method,
        path: String,
        _: A.Type = A.self,
        _: B.Type = B.self,
        middleware: [Middleware],
        respond: (Request, A, B) throws -> Response) {
        let keys = parseParameterKeys(path: path, count: 2)
        let responder = BasicResponder { request in
            let parameters = try self.parseParameters(
                keys: keys,
                pathParameters: request.pathParameters,
                count: 2
            )

            let a = try A(pathParameter: parameters[0])
            let b = try B(pathParameter: parameters[1])

            return try respond(request, a, b)
        }

        addRoute(method: method, path: path, middleware: middleware, responder: responder)
    }

    public func addRoute<
        A: PathParameterInitializable,
        B: PathParameterInitializable,
        C: PathParameterInitializable
        >(
        method: Method,
        path: String,
        _: A.Type = A.self,
        _: B.Type = B.self,
        _: C.Type = C.self,
        middleware: [Middleware],
        respond: (Request, A, B, C) throws -> Response) {
        let keys = parseParameterKeys(path: path, count: 3)
        let responder = BasicResponder { request in
            let parameters = try self.parseParameters(
                keys: keys,
                pathParameters: request.pathParameters,
                count: 3
            )

            let a = try A(pathParameter: parameters[0])
            let b = try B(pathParameter: parameters[1])
            let c = try C(pathParameter: parameters[2])

            return try respond(request, a, b, c)
        }

        addRoute(method: method, path: path, middleware: middleware, responder: responder)
    }

    public func addRoute<
        A: PathParameterInitializable,
        B: PathParameterInitializable,
        C: PathParameterInitializable,
        D: PathParameterInitializable
        >(
        method: Method,
        path: String,
        _: A.Type = A.self,
        _: B.Type = B.self,
        _: C.Type = C.self,
        _: D.Type = D.self,
        middleware: [Middleware],
        respond: (Request, A, B, C, D) throws -> Response) {
        let keys = parseParameterKeys(path: path, count: 4)
        let responder = BasicResponder { request in
            let parameters = try self.parseParameters(
                keys: keys,
                pathParameters: request.pathParameters,
                count: 4
            )

            let a = try A(pathParameter: parameters[0])
            let b = try B(pathParameter: parameters[1])
            let c = try C(pathParameter: parameters[2])
            let d = try D(pathParameter: parameters[3])

            return try respond(request, a, b, c, d)
        }

        addRoute(method: method, path: path, middleware: middleware, responder: responder)
    }

    public func addRoute<
        A: PathParameterInitializable,
        T: StructuredDataInitializable
        >(
        method: Method,
        path: String,
        _: A.Type = A.self,
        middleware: [Middleware],
        content: T.Type = T.self,
        respond: (Request, A, T) throws -> Response) {
        let keys = parseParameterKeys(path: path, count: 1)
        let contentMapper = ContentMapperMiddleware(mappingTo: content)
        let responder = BasicResponder { request in
            let parameters = try self.parseParameters(
                keys: keys,
                pathParameters: request.pathParameters,
                count: 1
            )

            let a = try A(pathParameter: parameters[0])

            guard let content = request.storage[T.key] as? T else {
                throw ClientError.badRequest
            }

            return try respond(request, a, content)
        }

        addRoute(method: method, path: path, middleware: [contentMapper] + middleware, responder: responder)
    }

    public func addRoute<
        A: PathParameterInitializable,
        B: PathParameterInitializable,
        T: StructuredDataInitializable
        >(
        method: Method,
        path: String,
        _: A.Type = A.self,
        _: B.Type = B.self,
        middleware: [Middleware],
        content: T.Type = T.self,
        respond: (Request, A, B, T) throws -> Response) {
        let keys = parseParameterKeys(path: path, count: 2)
        let contentMapper = ContentMapperMiddleware(mappingTo: content)
        let responder = BasicResponder { request in
            let parameters = try self.parseParameters(
                keys: keys,
                pathParameters: request.pathParameters,
                count: 2
            )

            let a = try A(pathParameter: parameters[0])
            let b = try B(pathParameter: parameters[1])
            guard let content = request.storage[T.key] as? T else {
                throw ClientError.badRequest
            }

            return try respond(request, a, b, content)
        }

        addRoute(method: method, path: path, middleware: [contentMapper] + middleware, responder: responder)
    }

    public func addRoute<
        A: PathParameterInitializable,
        B: PathParameterInitializable,
        C: PathParameterInitializable,
        T: StructuredDataInitializable
        >(
        method: Method,
        path: String,
        _: A.Type = A.self,
        _: B.Type = B.self,
        _: C.Type = C.self,
        middleware: [Middleware],
        content: T.Type = T.self,
        respond: (Request, A, B, C, T) throws -> Response) {
        let keys = parseParameterKeys(path: path, count: 3)
        let contentMapper = ContentMapperMiddleware(mappingTo: content)
        let responder = BasicResponder { request in
            let parameters = try self.parseParameters(
                keys: keys,
                pathParameters: request.pathParameters,
                count: 3
            )

            let a = try A(pathParameter: parameters[0])
            let b = try B(pathParameter: parameters[1])
            let c = try C(pathParameter: parameters[2])

            guard let content = request.storage[T.key] as? T else {
                throw ClientError.badRequest
            }

            return try respond(request, a, b, c, content)
        }

        addRoute(method: method, path: path, middleware: [contentMapper] + middleware, responder: responder)
    }

    public func addRoute<
        A: PathParameterInitializable,
        B: PathParameterInitializable,
        C: PathParameterInitializable,
        D: PathParameterInitializable,
        T: StructuredDataInitializable
        >(
        method: Method,
        path: String,
        _: A.Type = A.self,
        _: B.Type = B.self,
        _: C.Type = C.self,
        _: D.Type = D.self,
        middleware: [Middleware],
        content: T.Type = T.self,
        respond: (Request, A, B, C, D, T) throws -> Response) {
        let keys = parseParameterKeys(path: path, count: 4)
        let contentMapper = ContentMapperMiddleware(mappingTo: content)
        let responder = BasicResponder { request in
            let parameters = try self.parseParameters(
                keys: keys,
                pathParameters: request.pathParameters,
                count: 4
            )

            let a = try A(pathParameter: parameters[0])
            let b = try B(pathParameter: parameters[1])
            let c = try C(pathParameter: parameters[2])
            let d = try D(pathParameter: parameters[3])

            guard let content = request.storage[T.key] as? T else {
                throw ClientError.badRequest
            }

            return try respond(request, a, b, c, d, content)
        }

        addRoute(method: method, path: path, middleware: [contentMapper] + middleware, responder: responder)
    }

    private func parseParameters(keys: [String], pathParameters: [String: String], count: Int) throws -> [String] {
        //        Todo: Fix bug in TrieRouteMatcher https://github.com/Zewo/Zewo/issues/122
        guard pathParameters.count >= count else {
            throw ServerError.internalServerError
        }

        let parameters = keys.flatMap({ pathParameters[$0] })

        guard parameters.count == count else {
            throw ServerError.internalServerError
        }

        return parameters
    }

    // Todo: if there are repeated identifiers call malformedRoute
    private func parseParameterKeys(path: String, count: Int) -> [String] {
        let split = path.characters
            .split(separator: "/")
            .map(String.init)
        let keys = split
            .map({ $0.characters })
            .filter({ $0.first == ":" })
            .map({ $0.dropFirst() })
            .map({ String($0) })

        if keys.count != count {
            let message = "Invalid route \"\(path)\". The number of path parameters doesn't match the number of strong typed parameters in the route"
            malformedRoute(message: message)
        }

        return keys
    }

    private func malformedRoute(message: String) {
        // Todo: Add "strict" configuration for Router.
        // When strict mode is enabled every malformed
        // route will fatalerror. Otherwise it will just
        // print a warning.

        // if strict {
        //     fatalError("Error: \(message)")
        // } else {
        print("Warning: \(message)")
        // }
    }
}
