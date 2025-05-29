//
//  ImmersiveView.swift
//  Portal Box
//
//  Created by Rotem Cohen on 5/28/25.
//

import SwiftUI
import RealityKit
import RealityKitContent
import ARKit
import Combine

enum HeadDirection {
    case forward
    case backward
    case left
    case right
    case unknown
}

@MainActor
struct ImmersiveView: View {
    
    @State private var box = Entity() // to store our box
    @State private var headDirection: HeadDirection = .unknown
    @State private var timerCancellable: AnyCancellable?
    @State private var currentWorld: Entity? = nil
    
    @State private var world1: Entity? = nil
    @State private var world2: Entity? = nil
    @State private var world3: Entity? = nil
    @State private var world4: Entity? = nil
    
    private let session = ARKitSession()
    private let provider = WorldTrackingProvider()
    
    var body: some View {
        RealityView {
 content,
 attachments in
            // Add the initial RealityKit content
            if let scene = try? await Entity(named: "PortalBoxScene", in: realityKitContentBundle) {
                content.add(scene)
                
                // change the position of the box
                guard let box = scene.findEntity(named: "Box") else {
                    fatalError()
                }
                self.box = box
                box.position = [0, 1, -2] // meters
                box.scale *= [1,2,1] // make taller
                
                let world1 = await createWorld(
                    texture: "skybox1",
                    particleWorldName: "World1Scene",
                    content: content
                )
                let world1Portal = await createWorldPortal(
                    world: world1,
                    anchorName: "AnchorPortal1",
                    content: content,
                    scene: scene
                )
                world1Portal.transform.rotation = simd_quatf(angle: .pi/2, axis: [0, 0, -1])
                self.world1 = world1
                
                let world2 = await createWorld(
                    texture: "skybox2",
                    particleWorldName: "World2Scene",
                    content: content
                )
                let world2Portal = await createWorldPortal(
                    world: world2,
                    anchorName: "AnchorPortal2",
                    content: content,
                    scene: scene
                )
                world2Portal.transform.rotation = simd_quatf(angle: .pi/2, axis: [0, 0, 1])
                self.world2 = world2
                
                let world3 = await createWorld(
                    texture: "skybox3",
                    particleWorldName: "World3Scene",
                    content: content
                )
                let world3Portal = await createWorldPortal(
                    world: world3,
                    anchorName: "AnchorPortal3",
                    content: content,
                    scene: scene
                )
                world3Portal.transform.rotation = simd_quatf(angle: .pi/2, axis: [1, 0, 0])
                self.world3 = world3
                
                let world4 = await createWorld(
                    texture: "skybox4",
                    particleWorldName: "World4Scene",
                    content: content
                )
                let world4Portal = await createWorldPortal(
                    world: world4,
                    anchorName: "AnchorPortal4",
                    content: content,
                    scene: scene
                )
                world4Portal.transform.rotation = simd_quatf(angle: .pi/2, axis: [-1, 0, 0])
                self.world4 = world4
                
                if let attachment = attachments.entity(for: "HeadPose") {
                    attachment.position = [0, 0, 1]
                    box.addChild(attachment)
                }
            }
        } attachments: {
            Attachment(id: "HeadPose") {
                Text("Head Pose Label: \(headDirection)")
            }
        }
        .onAppear {
            Task {
                try? await session.run([provider])
            }
            
            timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect().sink { _ in
                let headPose = getHeadPose()
                getHeadDirection(headPose)
            }
        }
        .onDisappear {
            timerCancellable?.cancel()
        }
        .onChange(of: headDirection) {
            switch headDirection {
            case .forward:
                currentWorld = world3
                print("Looking forward - World 3 activated")
                // You can add visual feedback or transition effects here
            case .backward:
                // Optional: set world 3 as current when looking backward
                currentWorld = world4
                print("Looking backward - World 4 activated!")
            case .left:
                // Optional: set world 4 as current when looking left
                currentWorld = world1
                print("Looking left - World 1 activated!")
            case .right:
                // Optional: set world 2 as current when looking right
                currentWorld = world2
                print("Looking right - World 2 activated!")
            case .unknown:
                currentWorld = nil
                print("Head direction unknown")
            }
        }
        .onChange(of: currentWorld) { oldWorld, newWorld in
            if let oldWorld = oldWorld {
                setEmitterState(forWorld: oldWorld, state: .pause)
            }
            if let newWorld = newWorld {
                setEmitterState(forWorld: newWorld, state: .play)
            }
        }
        
    }
    
    func setEmitterState(forWorld world: Entity, state: ParticleEmitterComponent.SimulationState) {
        guard let emitter = world.findEntity(named: "ParticleEmitter") else { return }
        var emitterComp = emitter.components[ParticleEmitterComponent.self]!
        emitterComp.simulationState = state
        emitter.components.set(emitterComp)
        print("world set to \(state)")
    }
    
    func getHeadPose() -> simd_float4x4 {
        guard let device: DeviceAnchor = self.provider.queryDeviceAnchor(
            atTimestamp: CACurrentMediaTime()
        ) else { return .init() }
        return device.originFromAnchorTransform
    }
    
    func getHeadDirection(_ headPose: simd_float4x4) {
        let forward = -SIMD3<Float>(headPose.columns.2.x,
                                    headPose.columns.2.y,
                                    headPose.columns.2.z)
        let threshold: Float = 0.25
        let backThreshold: Float = 0.75
        if forward.x < -threshold {
            headDirection = .left
        } else if forward.x > threshold {
            headDirection = .right
        } else {
            if forward.z > backThreshold {
                headDirection = .backward
            } else {
                headDirection = .forward
            }
        }
    }
    
    func createWorld(texture: String, particleWorldName: String, content: RealityViewContent) async -> Entity {
        let world = Entity()
        world.components.set(WorldComponent())
        let skybox = await createSkyboxEntity(texture: texture)
        world.addChild(skybox)
        if let particleWorld = try? await Entity(named: particleWorldName, in: realityKitContentBundle) {
            particleWorld.position = [0, 3, 0]
            guard let emitter = particleWorld.findEntity(named: "ParticleEmitter") else {
                fatalError("Cannot find particle emitter")
            }
            var emitterComp = emitter.components[ParticleEmitterComponent.self]!
            emitterComp.simulationState = .pause
            emitter.components.set(emitterComp)
            world.addChild(particleWorld)
        }
        
        content.add(world)
        return world
    }
    
    func createWorldPortal(world: Entity, anchorName: String, content: RealityViewContent, scene: Entity) async -> Entity {
        let worldPortal = createPortal(target: world)
        content.add(worldPortal)
        
        guard let anchorPortal = scene.findEntity(named: anchorName) else {
            fatalError("Cannot find portal anchor")
        }
        
        anchorPortal.addChild(worldPortal)
        return worldPortal
    }
    
    func createPortal(target: Entity) -> Entity {
        let portalMesh = MeshResource.generatePlane(width: 1, depth: 1) // meters
        let portal = ModelEntity(mesh: portalMesh, materials: [PortalMaterial()])
        portal.components.set(PortalComponent(target: target))
        return portal
    }
    
    func createSkyboxEntity(texture: String) async -> Entity {
        guard let resource = try? await TextureResource(named: texture) else {
            fatalError("Unable to load the skybox")
        }
        
        var material = UnlitMaterial()
        material.color = .init(texture: .init(resource))
        
        let entity = Entity()
        entity.components.set(ModelComponent(
            mesh: .generateSphere(radius: 1000),
            materials: [material]
        ))
        entity.scale *= .init(x: -1, y: 1, z: 1) //inverse texture
        return entity
    }
}

//#Preview(immersionStyle: .mixed) {
//    ImmersiveView()
//        .environment(AppModel())
//}
